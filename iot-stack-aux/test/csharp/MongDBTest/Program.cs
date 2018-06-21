using System;
using System.Linq;
using MongoDB.Bson;
using MongoDB.Driver;
using System.Configuration;

namespace MongDBTest
{
    class Program
    {
        static void Main(string[] args)
        {
            string connectionStr = ConfigurationManager.AppSettings["mongo.connection"];
            Console.WriteLine(connectionStr);
            var client = new MongoClient(connectionStr);
            var database = client.GetDatabase("foodb7");
            var collection = database.GetCollection<BsonDocument>("bar");

            string propName = "Name";
            string propVal = "Jack";

            Console.WriteLine("Inserting \"{0}\" with value \"{1}\"", propName, propVal);
            collection.InsertOne(new BsonDocument("Name", "Jack"));

            Console.WriteLine("Listing \"{0}\" with value \"{1}\"", propName, propVal);
            var list = collection.Find(new BsonDocument("Name", "Jack")).ToList();

            foreach (var document in list)
            {
                Console.WriteLine(document["Name"]);
            }
        }
    }
}
