namespace TFXHub.Agent;

public class Worker : BackgroundService
{
    private readonly ILogger<Worker> _logger;
    private readonly HttpClient _httpClient;

    public Worker(ILogger<Worker> logger, IHttpClientFactory httpClientFactory, IConfiguration configuration)
    {
        _logger = logger;
        _httpClient = httpClientFactory.CreateClient("tfxhubAgent");

        var baseUrl = configuration.GetValue<string>("HOST_BASE_URL") ?? "http://localhost:5000";
        _httpClient.BaseAddress = new Uri(baseUrl);
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            await CheckHostHealthAsync(stoppingToken);
            await CheckUsersAsync(stoppingToken);
            await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
        }
    }

    private async Task CheckHostHealthAsync(CancellationToken stoppingToken)
    {
        await RetryAsync(async () =>
        {
            var response = await _httpClient.GetAsync("/api/health", stoppingToken);
            var health = await response.Content.ReadAsStringAsync(stoppingToken);
            _logger.LogInformation("Host health: {StatusCode} - {health}", response.StatusCode, health);
        }, stoppingToken);
    }

    private async Task CheckUsersAsync(CancellationToken stoppingToken)
    {
        await RetryAsync(async () =>
        {
            var response = await _httpClient.GetAsync("/api/users", stoppingToken);
            var users = await response.Content.ReadAsStringAsync(stoppingToken);
            _logger.LogInformation("Host users: {StatusCode} - {users}", response.StatusCode, users);
        }, stoppingToken);
    }

    private async Task RetryAsync(Func<Task> action, CancellationToken stoppingToken)
    {
        var retries = 0;
        var maxRetries = 4;

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await action();
                return;
            }
            catch (Exception ex)
            {
                retries++;
                if (retries > maxRetries)
                {
                    _logger.LogError(ex, "Max retries reached for host request.");
                    return;
                }

                var delay = TimeSpan.FromSeconds(Math.Pow(2, retries));
                _logger.LogWarning(ex, "Host unavailable; retry {Retry}/{MaxRetries} in {Delay} seconds.", retries, maxRetries, delay.TotalSeconds);
                await Task.Delay(delay, stoppingToken);
            }
        }
    }
}