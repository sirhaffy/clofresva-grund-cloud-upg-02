using MVC_TestApp.Models;
using FluentValidation;
using Microsoft.AspNetCore.Mvc;
using MVC_TestApp.Repositories;

namespace MVC_TestApp.Services;

public class NewsletterService : INewsletterService
{
    // Dependency injections
    private readonly ISubscriberRepository _repository;
    private readonly IValidator<Subscriber> _validator;
    
    public NewsletterService(ISubscriberRepository repository, IValidator<Subscriber> validator)
    {
        _repository = repository;
        _validator = validator;
    }
    
    // Implement the methods
    public async Task<OperationResult> SignUpAsync(Subscriber subscriber)
    {
        var validationResult = _validator.Validate(subscriber);

        if (!validationResult.IsValid)
        {
            return OperationResult.Failure(string.Join(", ", validationResult.Errors
                .Select(e => $"{e.PropertyName}: {e.ErrorMessage}")));
        }
    
        if (subscriber == null || string.IsNullOrWhiteSpace(subscriber.Email))
        {
            return OperationResult.Failure("Invalid subscriber information.");
        }

        if (await _repository.ExistsSubscriberAsync(subscriber.Email))
        {
            return OperationResult.Failure("You are already subscribed to our newsletter.");
        }

        var success = await _repository.AddSubscriberAsync(subscriber);

        return success
            ? OperationResult.Success($"Welcome to our newsletter, {subscriber.Name}! You'll receive updates soon.")
            : OperationResult.Failure("Failed to add your subscription. Please try again.");
    }


    public async Task<OperationResult> UnsubscribeAsync(string email)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(email))
            {
                return OperationResult.Failure("Invalid email address.");
            }

            var subscriber = await _repository.GetSubscriberAsync(email);
            if (subscriber == null)
            {
                return OperationResult.Failure("We couldn't find your subscription in our system.");
            }

            var success = await _repository.DeleteSubscriberAsync(email);
            return success
                ? OperationResult.Success("You have been successfully removed from our newsletter. We're sorry to see you go!")
                : OperationResult.Failure("Failed to remove your subscription. Please try again.");
        }
        catch (Exception ex)
        {
            // Log exception (lägg till en logger om det behövs)
            
            return OperationResult.Failure("An unexpected error occurred. Please try again later.");
        }
    }

    public async Task<IEnumerable<Subscriber>> GetSubscribersAsync()
    {
        // Get all subscribers from the repository and convert to List to match the interface
        var subscribers = await _repository.GetSubscribersAsync();
        return subscribers.ToList();
    }
    
}