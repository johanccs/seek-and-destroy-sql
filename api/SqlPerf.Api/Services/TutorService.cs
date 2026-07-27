using System.Text;
using System.Text.Json;
using SqlPerf.Api.Models;

namespace SqlPerf.Api.Services;

public sealed record TutorMessage(string Role, string Content, long Ts);

// A piece of a streamed tutor reply. Either a text delta to append, or (the last
// chunk) the finished message's cost once OpenRouter reports token usage.
public sealed record TutorStreamChunk(string? Delta, decimal? CostZar, int? PromptTokens, int? CompletionTokens);

// Streams chat completions from OpenRouter for the AI tutor, using the current
// lesson's narrative/topics as system context so answers stay on-topic.
public sealed class TutorService
{
    private readonly HttpClient _http;
    private readonly IConfiguration _cfg;
    private readonly ILogger<TutorService> _log;

    private (string Model, decimal PromptUsd, decimal CompletionUsd)? _pricing;
    private DateTime _pricingFetchedAt;
    private readonly SemaphoreSlim _pricingLock = new(1, 1);

    public TutorService(IHttpClientFactory httpFactory, IConfiguration cfg, ILogger<TutorService> log)
    {
        _http = httpFactory.CreateClient("openrouter");
        _cfg = cfg;
        _log = log;
    }

    public bool IsConfigured => !string.IsNullOrWhiteSpace(_cfg["OpenRouter:ApiKey"]);

    private string Model => _cfg["OpenRouter:Model"] ?? "openai/gpt-oss-20b:free";

    // Static approximation, not a live FX feed -- configurable via OpenRouter:UsdToZar.
    private decimal UsdToZar => decimal.TryParse(_cfg["OpenRouter:UsdToZar"], out var r) ? r : 18.5m;

    private static string BuildSystemPrompt(Lesson lesson) => $"""
        You are a friendly, patient SQL Server performance tutor embedded in an interactive
        learning app called "Seek & Destroy". The learner is currently on this lesson:

        Title: {lesson.Manifest.Title}
        Level: {lesson.Manifest.Level}
        Topics: {string.Join(", ", lesson.Manifest.Topics)}

        Lesson content (markdown) the learner has already read:
        ---
        {lesson.Manifest.Narrative}
        ---

        Answer the learner's questions about this lesson's concept, the SQL Server engine
        internals behind it, or how to reason about execution plans. Keep answers focused on
        this lesson unless the learner clearly asks something broader. Explain in plain,
        approachable language, the way you'd explain to a junior developer -- define any
        jargon or acronym the first time you use it.

        When a diagram would genuinely help (e.g. a B-tree index, a lock-wait chain, a plan
        tree, a partition layout), include a small, well-formatted SVG diagram in a fenced
        code block tagged ```svg. Keep SVGs simple (a few shapes/lines/text, viewBox set,
        no external references, no <script> or event handler attributes) and only include one
        per answer, when it clearly adds value -- most answers need no diagram at all.
        """;

    // OpenRouter reports per-token USD pricing on GET /models; cached for an hour so we
    // aren't hitting it on every chat turn.
    private async Task<(decimal PromptUsd, decimal CompletionUsd)?> GetPricingAsync(CancellationToken ct)
    {
        var model = Model;
        if (_pricing is { } cached && cached.Model == model && DateTime.UtcNow - _pricingFetchedAt < TimeSpan.FromHours(1))
            return (cached.PromptUsd, cached.CompletionUsd);

        await _pricingLock.WaitAsync(ct);
        try
        {
            if (_pricing is { } c2 && c2.Model == model && DateTime.UtcNow - _pricingFetchedAt < TimeSpan.FromHours(1))
                return (c2.PromptUsd, c2.CompletionUsd);

            using var res = await _http.GetAsync("https://openrouter.ai/api/v1/models", ct);
            if (!res.IsSuccessStatusCode) return null;
            using var doc = JsonDocument.Parse(await res.Content.ReadAsStreamAsync(ct));
            foreach (var m in doc.RootElement.GetProperty("data").EnumerateArray())
            {
                if (m.GetProperty("id").GetString() != model) continue;
                var pricing = m.GetProperty("pricing");
                var promptUsd = decimal.Parse(pricing.GetProperty("prompt").GetString() ?? "0");
                var completionUsd = decimal.Parse(pricing.GetProperty("completion").GetString() ?? "0");
                _pricing = (model, promptUsd, completionUsd);
                _pricingFetchedAt = DateTime.UtcNow;
                return (promptUsd, completionUsd);
            }
            return null;
        }
        catch (Exception ex)
        {
            _log.LogWarning(ex, "Failed to fetch OpenRouter model pricing for {Model}", model);
            return null;
        }
        finally { _pricingLock.Release(); }
    }

    public async IAsyncEnumerable<TutorStreamChunk> StreamReplyAsync(
        Lesson lesson, IReadOnlyList<TutorMessage> history, string userMessage,
        [System.Runtime.CompilerServices.EnumeratorCancellation] CancellationToken ct)
    {
        var apiKey = _cfg["OpenRouter:ApiKey"];
        if (string.IsNullOrWhiteSpace(apiKey))
            throw new InvalidOperationException("OpenRouter API key is not configured (set OpenRouter:ApiKey / OPENROUTER_API_KEY).");

        var messages = new List<object> { new { role = "system", content = BuildSystemPrompt(lesson) } };
        foreach (var m in history)
            messages.Add(new { role = m.Role, content = m.Content });
        messages.Add(new { role = "user", content = userMessage });

        var payload = JsonSerializer.Serialize(new
        {
            model = Model,
            messages,
            stream = true,
            stream_options = new { include_usage = true },
        }, Json.Options);

        using var req = new HttpRequestMessage(HttpMethod.Post, "https://openrouter.ai/api/v1/chat/completions")
        {
            Content = new StringContent(payload, Encoding.UTF8, "application/json"),
        };
        req.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", apiKey);
        req.Headers.Add("HTTP-Referer", "https://seek-and-destroy-sql.app");
        req.Headers.Add("X-Title", "Seek & Destroy SQL");

        using var res = await _http.SendAsync(req, HttpCompletionOption.ResponseHeadersRead, ct);
        if (!res.IsSuccessStatusCode)
        {
            var body = await res.Content.ReadAsStringAsync(ct);
            _log.LogWarning("OpenRouter error {Status}: {Body}", res.StatusCode, body);
            throw new InvalidOperationException($"OpenRouter request failed ({(int)res.StatusCode}): {body}");
        }

        var pricing = await GetPricingAsync(ct);

        await using var stream = await res.Content.ReadAsStreamAsync(ct);
        using var reader = new StreamReader(stream);
        while (!reader.EndOfStream)
        {
            var line = await reader.ReadLineAsync(ct);
            if (string.IsNullOrWhiteSpace(line) || !line.StartsWith("data:")) continue;
            var data = line["data:".Length..].Trim();
            if (data == "[DONE]") yield break;

            string? delta = null;
            int? promptTokens = null, completionTokens = null;
            try
            {
                using var doc = JsonDocument.Parse(data);
                var root = doc.RootElement;
                if (root.TryGetProperty("choices", out var choices) && choices.GetArrayLength() > 0)
                {
                    delta = choices[0].GetProperty("delta").TryGetProperty("content", out var c)
                        ? c.GetString() : null;
                }
                if (root.TryGetProperty("usage", out var usage) && usage.ValueKind == JsonValueKind.Object)
                {
                    promptTokens = usage.GetProperty("prompt_tokens").GetInt32();
                    completionTokens = usage.GetProperty("completion_tokens").GetInt32();
                }
            }
            catch (JsonException) { /* keep-alive / malformed chunk, skip */ }

            if (!string.IsNullOrEmpty(delta))
                yield return new TutorStreamChunk(delta, null, null, null);

            if (promptTokens is not null && completionTokens is not null)
            {
                decimal? costZar = pricing is { } p
                    ? (promptTokens.Value * p.PromptUsd + completionTokens.Value * p.CompletionUsd) * UsdToZar
                    : null;
                yield return new TutorStreamChunk(null, costZar, promptTokens, completionTokens);
            }
        }
    }
}
