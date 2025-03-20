using System.ComponentModel.DataAnnotations;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace MVC_TestApp.Models;

public class Subscriber
{
    
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string? Id { get; set; }
    
    [Required]
    [StringLength(20, ErrorMessage = "Name is too long (20).")]
    [BsonElement("name")]
    public string? Name { get; set; }
    
    [Required]
    [EmailAddress]
    [BsonElement("email")]
    public string? Email { get; set; }
    
}