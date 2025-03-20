using MVC_TestApp.Storage;

namespace MVC_TestApp.Services;

public class AzureBlobImageService : IImageService
{
    private readonly IConfiguration _configuration;

    public AzureBlobImageService(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public string GetImageUrl(string imageName)
    {
        // Check the flag to see if Azure Storage should be used.
        bool useAzureStorage = _configuration.GetValue<bool>("FEATUREFLAGS:USEAZURESTORAGE", false);

        if (!useAzureStorage)
        {
            // Return a local URL to the image.
            return $"/images/{imageName}";
        }

        // Get the Azure Blob Storage configuration.
        var accountName = _configuration["Storage:AccountName"];
        var blobEndpoint = _configuration["Storage:BlobEndpoint"];
        var containerName = _configuration["Storage:ContainerName"] ?? "appdata";;

        if (!string.IsNullOrEmpty(blobEndpoint))
        {
            return $"{blobEndpoint.TrimEnd('/')}/{containerName}/{imageName}";
        }

        if (string.IsNullOrWhiteSpace(accountName) || string.IsNullOrWhiteSpace(containerName))
        {
            throw new InvalidOperationException("Azure Blob Storage-konfiguration saknas.");
        }

        return $"https://{accountName}.blob.core.windows.net/{containerName}/{imageName}";
    }
}