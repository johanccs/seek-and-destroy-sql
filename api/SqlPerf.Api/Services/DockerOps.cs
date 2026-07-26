using System.Diagnostics;

namespace SqlPerf.Api.Services;

public sealed record DockerStepResult(string Step, bool Success, string Output);

// Drives disaster-recovery Docker operations (recreate the sqlserver container/image/
// volume) via the host Docker daemon, reached through the socket bind-mounted into this
// container (see docker-compose.yml). This is only safe in a trusted local/dev
// environment -- the mounted socket gives this container full control of the host's
// Docker daemon.
public sealed class DockerOps
{
    private const string ContainerName = "sqlperf-sqlserver";
    private const string ImageName = "mcr.microsoft.com/mssql/server:2022-latest";
    private const string VolumeName = "sql-performance_mssql-data";
    private const string ComposeFile = "/workspace/docker-compose.yml";
    private const string ProjectDir = "/workspace";
    private const string ProjectName = "sql-performance";

    public async Task<List<DockerStepResult>> RecreateSqlContainerAsync(bool keepData, CancellationToken ct)
    {
        var steps = new List<DockerStepResult>();

        // Best-effort cleanup steps: a missing container/image/volume is not an error.
        steps.Add(await Run("stop-and-remove-container", "docker", $"rm -f {ContainerName}", ct));
        steps.Add(await Run("remove-image", "docker", $"rmi {ImageName}", ct));

        if (!keepData)
            steps.Add(await Run("remove-data-volume", "docker", $"volume rm {VolumeName}", ct));

        var pull = await Run("pull-fresh-image", "docker", $"pull {ImageName}", ct, timeoutSec: 300);
        steps.Add(pull);
        if (!pull.Success) return steps;

        var recreate = await Run("recreate-container", "docker",
            $"compose --project-name {ProjectName} -f {ComposeFile} --project-directory {ProjectDir} up -d sqlserver",
            ct, timeoutSec: 120);
        steps.Add(recreate);
        if (!recreate.Success) return steps;

        steps.Add(await WaitHealthyAsync(ct));
        return steps;
    }

    private async Task<DockerStepResult> WaitHealthyAsync(CancellationToken ct)
    {
        var deadline = DateTime.UtcNow.AddMinutes(3);
        string last = "";
        while (DateTime.UtcNow < deadline && !ct.IsCancellationRequested)
        {
            var r = await Run("check-health", "docker",
                $"inspect --format={{{{.State.Health.Status}}}} {ContainerName}", ct, timeoutSec: 10);
            last = r.Output.Trim();
            if (last == "healthy") return new DockerStepResult("wait-for-healthy", true, "healthy");
            await Task.Delay(5000, ct);
        }
        return new DockerStepResult("wait-for-healthy", false, $"did not become healthy in time (last status: {last})");
    }

    private static async Task<DockerStepResult> Run(
        string step, string fileName, string arguments, CancellationToken ct, int timeoutSec = 60)
    {
        try
        {
            var psi = new ProcessStartInfo(fileName, arguments)
            {
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
            };
            using var proc = Process.Start(psi)!;
            using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
            cts.CancelAfter(TimeSpan.FromSeconds(timeoutSec));

            var stdout = await proc.StandardOutput.ReadToEndAsync(cts.Token);
            var stderr = await proc.StandardError.ReadToEndAsync(cts.Token);
            await proc.WaitForExitAsync(cts.Token);

            var output = (stdout + stderr).Trim();
            return new DockerStepResult(step, proc.ExitCode == 0, output);
        }
        catch (OperationCanceledException)
        {
            return new DockerStepResult(step, false, "timed out");
        }
        catch (Exception ex)
        {
            return new DockerStepResult(step, false, ex.Message);
        }
    }
}
