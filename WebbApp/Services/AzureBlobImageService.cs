using MVC_TestApp.Storage;
using Microsoft.Extensions.Configuration;

namespace MVC_TestApp.Services;

public class AzureBlobImageService : IImageService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<AzureBlobImageService> _logger;

    public AzureBlobImageService(IConfiguration configuration, ILogger<AzureBlobImageService> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<string> UploadImageAsync(IFormFile image)
    {
        // Generate a unique filename
        string uniqueFileName = $"{Guid.NewGuid()}-{Path.GetFileName(image.FileName)}";

        _logger.LogInformation("Uploading image {FileName} to Azure Blob Storage", uniqueFileName);

        // Get the container URL from configuration
        string storageAccount = _configuration["Storage:AccountName"] ?? "";
        string blobEndpoint = _configuration["Storage:BlobEndpoint"] ?? "";
        string containerName = _configuration["Storage:ContainerName"] ?? "appdata";

        _logger.LogInformation("Storage Account: {StorageAccount}", storageAccount);
        _logger.LogInformation("Blob Endpoint: {BlobEndpoint}", blobEndpoint);
        _logger.LogInformation("Container Name: {ContainerName}", containerName);

        if (string.IsNullOrEmpty(blobEndpoint) || string.IsNullOrEmpty(storageAccount))
        {
            _logger.LogError("Azure Blob Storage configuration is missing or incomplete");
            throw new InvalidOperationException("Azure Blob Storage configuration is missing or incomplete");
        }

        // Create a BlobClient for the blob
        string containerUrl = $"{blobEndpoint.TrimEnd('/')}/{containerName}";
        _logger.LogInformation("Container URL: {ContainerUrl}", containerUrl);

        // This is a simplified approach - in production, you'd use Azure.Storage.Blobs SDK
        try
        {
            // Here we would use Azure SDK to upload blob
            // For now, just returning the URL where the image would be
            return $"{containerUrl}/{uniqueFileName}";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error uploading image to Azure Blob Storage");
            throw;
        }
    }

    public string GetImageUrl(string imageName)
    {
        string storageAccount = _configuration["Storage:AccountName"] ?? "";
        string blobEndpoint = _configuration["Storage:BlobEndpoint"] ?? "";
        string containerName = _configuration["Storage:ContainerName"] ?? "appdata";

        // todo: Remove after
        _logger.LogInformation("Gets blobEndpoint: {BlobEndpoint}", blobEndpoint);
        _logger.LogInformation("Gets storageAccount: {StorageAccount}", storageAccount);
        _logger.LogInformation("Gets containerName: {ContainerName}", containerName);

        if (string.IsNullOrEmpty(blobEndpoint))
        {
            if (string.IsNullOrEmpty(storageAccount))
            {
                _logger.LogError("Azure Blob Storage configuration is missing");
                throw new InvalidOperationException("Azure Blob Storage configuration is missing");
            }

            // Construct URL from storage account name if endpoint not provided
            blobEndpoint = $"https://{storageAccount}.blob.core.windows.net";
        }

        return $"{blobEndpoint.TrimEnd('/')}/{containerName}/{imageName}";
    }
}