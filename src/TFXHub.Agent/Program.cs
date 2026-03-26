using Serilog;
using OpenTelemetry;
using OpenTelemetry.Trace;
using TFXHub.Agent;

IHost host = Host.CreateDefaultBuilder(args)
    .UseSerilog((context, config) =>
        config
            .WriteTo.Console()
            .WriteTo.File("logs/tfxhub-agent-.log", rollingInterval: RollingInterval.Day, retainedFileCountLimit: 7))
    .ConfigureServices((context, services) =>
    {
        services.AddHttpClient("tfxhubAgent");
        services.AddHostedService<Worker>();
        services.AddOpenTelemetry()
            .WithTracing(tracerProviderBuilder =>
                tracerProviderBuilder
                    .AddHttpClientInstrumentation()
                    .AddSource("TFXHub.Agent")
                    .AddConsoleExporter());
    })
    .Build();

await host.RunAsync();