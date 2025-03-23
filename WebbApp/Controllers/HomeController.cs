using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using MVC_TestApp.Models;
using MVC_TestApp.Storage;

namespace MVC_TestApp.Controllers;

public class HomeController : Controller
{
    private readonly ILogger<HomeController> _logger;
    private readonly IImageService _imageService;

    public HomeController(ILogger<HomeController> logger, IImageService imageService)
    {
        _logger = logger;
        _imageService = imageService;
    }

    public IActionResult Index()
    {
        ViewData["DeckardImageUrl"] = _imageService.GetImageUrl("badfon-art-starik-rebenok-igrushka.jpg");
        return View();
    }

    public IActionResult Privacy()
    {
        return View();
    }

    public IActionResult About()
    {
        // Get hero image URL from the image service
        ViewData["HeroImageUrl"] = _imageService.GetImageUrl("hero.jpg");

        return View();
    }

    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
    }

}
