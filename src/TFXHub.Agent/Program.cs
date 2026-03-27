using OpenTelemetry;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using Serilog;
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
                    .SetResourceBuilder(ResourceBuilder.CreateDefault().AddService("TFXHub.Agent"))
                    .AddHttpClientInstrumentation()
                    .AddSource("TFXHub.Agent")
                    .AddConsoleExporter());
    })
    .Build();

await host.RunAsync();
