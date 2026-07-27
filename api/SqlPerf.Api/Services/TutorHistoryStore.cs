using System.Text.Json;
using SqlPerf.Api.Models;

namespace SqlPerf.Api.Services;

// Persists AI tutor chat history to one JSON file per lesson on local disk. This is a
// learning playground, not a multi-user product, so a simple file store (rather than a
// DB table) is enough -- history survives app restarts and container recreation as long
// as the volume/bind-mount that holds it persists.
public sealed class TutorHistoryStore
{
    private readonly string _dir;
    private readonly SemaphoreSlim _lock = new(1, 1);

    public TutorHistoryStore(IConfiguration cfg)
    {
        _dir = cfg["Tutor:HistoryPath"] ?? Path.Combine(AppContext.BaseDirectory, "tutor-history");
        Directory.CreateDirectory(_dir);
    }

    private string PathFor(string lessonId) => Path.Combine(_dir, $"{Sanitize(lessonId)}.json");

    private static string Sanitize(string id) =>
        string.Concat(id.Where(c => char.IsLetterOrDigit(c) || c is '-' or '_'));

    public async Task<List<TutorMessage>> LoadAsync(string lessonId, CancellationToken ct = default)
    {
        var path = PathFor(lessonId);
        if (!File.Exists(path)) return new();
        await _lock.WaitAsync(ct);
        try
        {
            var json = await File.ReadAllTextAsync(path, ct);
            return JsonSerializer.Deserialize<List<TutorMessage>>(json, Json.Options) ?? new();
        }
        finally { _lock.Release(); }
    }

    public async Task<List<TutorMessage>> AppendAsync(string lessonId, TutorMessage message, CancellationToken ct = default)
    {
        await _lock.WaitAsync(ct);
        try
        {
            var path = PathFor(lessonId);
            var list = File.Exists(path)
                ? JsonSerializer.Deserialize<List<TutorMessage>>(await File.ReadAllTextAsync(path, ct), Json.Options) ?? new()
                : new();
            list.Add(message);
            await File.WriteAllTextAsync(path, JsonSerializer.Serialize(list, Json.Options), ct);
            return list;
        }
        finally { _lock.Release(); }
    }

    public async Task ClearAsync(string lessonId, CancellationToken ct = default)
    {
        await _lock.WaitAsync(ct);
        try { File.Delete(PathFor(lessonId)); }
        finally { _lock.Release(); }
    }
}
