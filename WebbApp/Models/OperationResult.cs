namespace MVC_TestApp.Models;

public class OperationResult
{
    public bool Succeeded { get; set; }
    public string Message { get; set; }
    
    public OperationResult(bool success, string message)
    {
        Succeeded = success;
        Message = message;
    }
    
    public static OperationResult Success(string message) => 
        new OperationResult(true, message);
    
    public static OperationResult Failure(string message) => 
        new OperationResult(false, message);  
}