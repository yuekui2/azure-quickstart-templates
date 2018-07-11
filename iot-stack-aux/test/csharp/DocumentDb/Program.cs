using Microsoft.Azure.Documents;
using Microsoft.Azure.Documents.Client;
using Microsoft.Azure.Documents.Client.TransientFaultHandling;
using Microsoft.Practices.EnterpriseLibrary.TransientFaultHandling;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Threading.Tasks;

namespace DocumentDb
{
	public class Program
	{
		public static void Main(string[] args)
		{
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            ServicePointManager.ServerCertificateValidationCallback += new RemoteCertificateValidationCallback(ValidateCertificate);
            var connectionPolicy = new ConnectionPolicy
			{
				ConnectionMode = ConnectionMode.Gateway,
				ConnectionProtocol = Protocol.Https,
				RetryOptions = new RetryOptions
				{
					// turning off internal retry strategy as we loose control and it doesn't work as expected
					MaxRetryAttemptsOnThrottledRequests = 0,
					MaxRetryWaitTimeInSeconds = 0
				}
			};
            //endpoint=https://localhost:8081;authKeyType=PrimaryMasterKey;authKey=C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==
            string uri = "https://10.0.2.10:8081/";
			IReliableReadWriteDocumentClient client = new DocumentClient(new Uri(args[0]),
                    "lf2YxcQQS1etfXeEsxFavN7k4isJOjOC+wnJuUbZnvBUzMe7GsHg5SQXTI8nQyTXkM3i2eJOCE3nFvP7N//2CQ==",
					connectionPolicy).AsReliable(RetryStrategy.DefaultExponential);

            //DocumentClient client = new DocumentClient(
            //	new Uri("https://10.0.0.4:8081"),
            //	"lf2YxcQQS1etfXeEsxFavN7k4isJOjOC+wnJuUbZnvBUzMe7GsHg5SQXTI8nQyTXkM3i2eJOCE3nFvP7N//2CQ==");
            //Database database = client.CreateDatabaseQuery().Where(db => db.Id.ToUpper() == "test").AsEnumerable().FirstOrDefault();

            Console.WriteLine("Client created with GenKey");
			var response = client.CreateDatabaseIfNotExistsAsync(new Database { Id = "test" }).GetAwaiter().GetResult();
			var database = response.Resource;
			Console.WriteLine($"Database test created.");

			//var result = client.CreateDatabaseQuery().Where(d => d.Id == args[0]);
			//Database database = null;
			//if (!result.AsEnumerable().Any())
			//{
			//	Console.WriteLine($"Database {args[0]} does not exist.");
			//	var response = client.CreateDatabaseIfNotExistsAsync(new Database { Id = args[0] }).GetAwaiter().GetResult();
			//	database = response.Resource;
			//	Console.WriteLine($"Database {args[0]} created.");
			//}
			//else
			//{
			//	database = result.AsEnumerable().FirstOrDefault();
			//	Console.WriteLine($"Database {args[0]} exists.");
			//}

			client.CreateDocumentCollectionIfNotExistsAsync(
			   database.SelfLink,
			   new DocumentCollection()
			   {
				   Id = "testcol",
				   PartitionKey = new PartitionKeyDefinition()
				   {
					   Paths = new Collection<string>
					   {
							"/partitionKey"
					   }
				   },
				   DefaultTimeToLive = -1
			   },
			   new RequestOptions()
			   {
				   ConsistencyLevel = ConsistencyLevel.BoundedStaleness,
				   OfferThroughput = 500
			   }).GetAwaiter().GetResult();

			Console.WriteLine($"Collection testcol created.");

			//client.DeleteDatabaseAsync()

			Console.ReadLine();

		}

		public static bool ValidateCertificate(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors errors)
		{
			return true;
		}
	}
}
