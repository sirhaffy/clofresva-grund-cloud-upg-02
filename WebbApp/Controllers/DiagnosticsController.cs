using Microsoft.AspNetCore.Mvc;
using MVC_TestApp.Models;
using MVC_TestApp.Repositories;
using System;
using System.Text.Json;
using System.Threading.Tasks;

namespace MVC_TestApp.Controllers
{
    public class DiagnosticsController : Controller
    {
        private readonly ISubscriberRepository _repository;
        private readonly IConfiguration _configuration;
        private readonly ILogger<DiagnosticsController> _logger;

        public DiagnosticsController(
            ISubscriberRepository repository,
            IConfiguration configuration,
            ILogger<DiagnosticsController> logger)
        {
            _repository = repository;
            _configuration = configuration;
            _logger = logger;
        }

        public async Task<IActionResult> Index()
        {
            var model = new DiagnosticsViewModel
            {
                RepositoryType = _repository.GetType().Name,
                HasMongoConnectionString = !string.IsNullOrEmpty(_configuration["MongoDB:ConnectionString"]),
                MongoConnectionStringLength = (_configuration["MongoDB:ConnectionString"] ?? "").Length,
                StorageAccountName = _configuration["Storage:AccountName"] ?? string.Empty,
                BlobEndpoint = _configuration["Storage:BlobEndpoint"] ?? string.Empty,
                FeatureFlagUseAzureStorage = _configuration.GetValue<bool>("FEATUREFLAGS:USEAZURESTORAGE"),
                SubscriberCount = (await _repository.GetSubscribersAsync()).Count()
            };

            return View(model);
        }
    }

    public class DiagnosticsViewModel
    {
        public string RepositoryType { get; set; } = string.Empty;
        public bool HasMongoConnectionString { get; set; }
        public int MongoConnectionStringLength { get; set; }
        public string StorageAccountName { get; set; } = string.Empty;
        public string BlobEndpoint { get; set; } = string.Empty;
        public bool FeatureFlagUseAzureStorage { get; set; }
        public int SubscriberCount { get; set; }
    }
}