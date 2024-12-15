using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace app_code
{
    public class HTTPFunction
    {
        private readonly ILogger<HTTPFunction> _logger;

        public HTTPFunction(ILogger<HTTPFunction> logger)
        {
            _logger = logger;
        }

        [Function("HTTPFunction")]
        public async Task<IActionResult> Run([HttpTrigger(AuthorizationLevel.Anonymous, "get", "post")] HttpRequest req)
        {
            _logger.LogInformation("C# HTTP trigger function processed a request.");

            int DelayInMilliseconds = 5000;
            await Task.Delay(DelayInMilliseconds);

            return new OkObjectResult("Welcome to Azure Functions!");
        }
    }
}
