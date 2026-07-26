using System.Text.Json;
using SqlPerf.Api.Models;

namespace SqlPerf.Api.Services;

// Loads lessons/<level>/<id>/{manifest.json,seed.sql,solution.sql} into memory.
public sealed class LessonCatalog
{
    private readonly Dictionary<string, Lesson> _byId = new(StringComparer.OrdinalIgnoreCase);
    private readonly ILogger<LessonCatalog> _log;

    public LessonCatalog(IConfiguration cfg, ILogger<LessonCatalog> log)
    {
        _log = log;
        var path = ResolveLessonsPath(cfg["Lessons:Path"]);
        if (path is null) { _log.LogWarning("No lessons path found; catalog empty."); return; }
        Load(path);
        _log.LogInformation("Loaded {Count} lessons from {Path}", _byId.Count, path);
    }

    private static string? ResolveLessonsPath(string? configured)
    {
        var candidates = new[]
        {
            configured,
            "/lessons",
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "lessons"),
            Path.Combine(Directory.GetCurrentDirectory(), "..", "..", "lessons"),
            Path.Combine(Directory.GetCurrentDirectory(), "lessons"),
        };
        foreach (var c in candidates)
        {
            if (string.IsNullOrWhiteSpace(c)) continue;
            var full = Path.GetFullPath(c);
            if (Directory.Exists(full) && Directory.EnumerateDirectories(full).Any())
                return full;
        }
        return null;
    }

    private void Load(string root)
    {
        foreach (var manifestPath in Directory.EnumerateFiles(root, "manifest.json", SearchOption.AllDirectories))
        {
            try
            {
                var dir = Path.GetDirectoryName(manifestPath)!;
                var manifest = JsonSerializer.Deserialize<Manifest>(File.ReadAllText(manifestPath), Json.Options);
                if (manifest is null || string.IsNullOrWhiteSpace(manifest.Id)) continue;

                var seed = ReadIfExists(Path.Combine(dir, "seed.sql"));
                var solution = ReadIfExists(Path.Combine(dir, "solution.sql"));
                var db = string.IsNullOrWhiteSpace(manifest.Database)
                    ? "Lesson_" + manifest.Id.Replace('-', '_')
                    : manifest.Database;

                _byId[manifest.Id] = new Lesson
                {
                    Manifest = manifest,
                    SeedSql = seed,
                    SolutionSql = solution,
                    Database = db,
                };
            }
            catch (Exception ex)
            {
                _log.LogError(ex, "Failed to load lesson at {Path}", manifestPath);
            }
        }
    }

    private static string ReadIfExists(string p) => File.Exists(p) ? File.ReadAllText(p) : "";

    public int Count => _byId.Count;
    public IReadOnlyCollection<Lesson> All => _byId.Values;
    public Lesson? Get(string id) => _byId.TryGetValue(id, out var l) ? l : null;
}
