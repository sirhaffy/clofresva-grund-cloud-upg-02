using FluentValidation;
using MVC_TestApp.Models;

namespace MVC_TestApp.Controllers;

public class UserValidator : AbstractValidator<Subscriber>
{
    public UserValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty().WithMessage("Email is required.")
            .EmailAddress().WithMessage("Invalid email format.")
            .Matches(@"^[^@\s]+@[^@\s]+\.[^@\s]+$").WithMessage("Email must contain a valid domain.");
    }
}