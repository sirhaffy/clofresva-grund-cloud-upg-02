using Microsoft.AspNetCore.Mvc;
using MVC_TestApp.Models;
using MVC_TestApp.Repositories;
using System;
using System.Text.Json;
using System.Threading.Tasks;
using MVC_TestApp.Storage;

namespace MVC_TestApp.Controllers
{
    public class DiagnosticsController : Controller
    {
        private readonly ISubscriberRepository _repository;
        private readonly IConfiguration _configuration;
        private readonly ILogger<DiagnosticsController> _logger;
        private readonly IImageService _imageService;

        public DiagnosticsController(
            ISubscriberRepository repository,
            IConfiguration configuration,
            ILogger<DiagnosticsController> logger,
            IImageService imageService)
        {
            _repository = repository;
            _configuration = configuration;
            _logger = logger;
            _imageService = imageService;
        }

        public async Task<IActionResult> Index()
        {
            string storageAccount = _configuration["Storage:AccountName"] ?? string.Empty;
            string blobEndpoint = _configuration["Storage:BlobEndpoint"] ?? string.Empty;
            string containerName = _configuration["Storage:ContainerName"] ?? "appdata";

            // Konstruera testbild-URL
            string testImageName = "hero.jpg"; // Byt till ett bildnamn som finns
            string constructedBlobUrl = string.Empty;

            // Få den riktiga URL:en från ImageService
            string testImageUrl = string.Empty;
            try {
                testImageUrl = _imageService.GetImageUrl(testImageName);
            }
            catch (Exception ex) {
                _logger.LogError(ex, "Error getting test image URL");
            }

            // Försök konstruera en URL manuellt för verifiering/jämförelse
            if (!string.IsNullOrEmpty(blobEndpoint)) {
                constructedBlobUrl = $"{blobEndpoint.TrimEnd('/')}/{containerName}/{testImageName}";
            }
            else if (!string.IsNullOrEmpty(storageAccount)) {
                constructedBlobUrl = $"https://{storageAccount}.blob.core.windows.net/{containerName}/{testImageName}";
            }

            var model = new DiagnosticsViewModel
            {
                RepositoryType = _repository.GetType().Name,
                HasMongoConnectionString = !string.IsNullOrEmpty(_configuration["MongoDB:ConnectionString"]),
                MongoConnectionStringLength = (_configuration["MongoDB:ConnectionString"] ?? "").Length,
                StorageAccountName = _configuration["Storage:AccountName"] ?? string.Empty,
                BlobEndpoint = _configuration["Storage:BlobEndpoint"] ?? string.Empty,
                FeatureFlagUseAzureStorage = _configuration.GetValue<bool>("FEATUREFLAGS:USEAZURESTORAGE"),
                SubscriberCount = (await _repository.GetSubscribersAsync()).Count(),

                ContainerName = containerName,
                ConstructedBlobUrl = constructedBlobUrl,
                TestImageUrl = testImageUrl,
                BlobStorageConfigured = !string.IsNullOrEmpty(blobEndpoint) || !string.IsNullOrEmpty(storageAccount),
                ImageServiceType = _imageService.GetType().Name
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
        public string ContainerName { get; set; } = string.Empty;
        public string ConstructedBlobUrl { get; set; } = string.Empty;
        public string TestImageUrl { get; set; } = string.Empty;
        public bool BlobStorageConfigured { get; set; }
        public string ImageServiceType { get; set; } = string.Empty;
    }
}