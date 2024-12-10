using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace test
{
    public class FirstFunction
    {
        private readonly ILogger<FirstFunction> _logger;

        public FirstFunction(ILogger<FirstFunction> logger)
        {
            _logger = logger;
        }

        [Function("FirstFunction")]
        public IActionResult Run([HttpTrigger(AuthorizationLevel.Function, "get", "post")] HttpRequest req)
        {
            _logger.LogInformation("C# HTTP trigger function processed a request.");
            return new OkObjectResult("Changed to system assigned identity!");
        }
    }
}
