using MVC_TestApp.Models;
using MVC_TestApp.Services;
using Microsoft.AspNetCore.Mvc;

namespace MVC_TestApp.Controllers;

public class NewsletterController : Controller
{
    
    private readonly INewsletterService _newsletterService;
    
    public NewsletterController(INewsletterService newsletterService)
    {
        _newsletterService = newsletterService;
    }
    
    // GET
    [HttpGet]
    public IActionResult Subscribe()
    {
        return View();
    }
    
    // POST
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Subscribe(Subscriber subscriber)
    {
        if (!ModelState.IsValid)
        {
            return View(subscriber);
        }
        
        var result = await _newsletterService.SignUpAsync(subscriber);
        
        if (!result.Succeeded)
        {
            ModelState.AddModelError("Email", result.Message);
            return View(subscriber);
        }
        
        // Write to the console (for debugging)
        Console.WriteLine($"New subscription: {subscriber.Name} - {subscriber.Email}");
        
        // Send a message to the user
        TempData["SuccessMessage"] = result.Message;
        
        return RedirectToAction(nameof(Subscribe));
    }

    // GET Subscribers
    public async Task<IActionResult> Subscribers()
    {
        var subscribers = await _newsletterService.GetSubscribersAsync();
        return View(subscribers);
    }
    
    // Post Unsubscribe
    [HttpPost] // Uses HttpPost to prevent accidental unsubscribes via GET requests
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Unsubscribe(string email)
    {
        if (string.IsNullOrEmpty(email))
        {
            TempData["ErrorMessage"] = "Email is required for unsubscribing";
            return RedirectToAction(nameof(Subscribers));
        }

        try
        {
            var result = await _newsletterService.UnsubscribeAsync(email);
        
            if (result.Succeeded)
            {
                TempData["SuccessMessage"] = result.Message;
            }
            else
            {
                TempData["ErrorMessage"] = result.Message;
            }
        }
        catch (Exception ex)
        {
            TempData["ErrorMessage"] = $"Error unsubscribing: {ex.Message}";
        }
    
        return RedirectToAction(nameof(Subscribers));
    }
}