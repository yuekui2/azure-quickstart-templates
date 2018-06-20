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
            var client = new MongoClient();
            var database = client.GetDatabase("foodb7");
            var collection = database.GetCollection<BsonDocument>("bar");
            collection.InsertOne(new BsonDocument("Name", "Jack"));

            var list = collection.Find(new BsonDocument("Name", "Jack")).ToList();

            foreach (var document in list)
            {
                Console.WriteLine(document["Name"]);
            }
        }
    }
}
