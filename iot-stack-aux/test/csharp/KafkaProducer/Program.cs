using System;
using System.Configuration;
using System.Text;
using System.Collections.Generic;
using Confluent.Kafka;
using Confluent.Kafka.Serialization;

public class Program
{
    public static void Main(string[] args)
    {
        var config = new Dictionary<string, object>
    {
        { "bootstrap.servers", ConfigurationManager.AppSettings["kafka.connection"] }
    };

        using (var producer = new Producer<Null, string>(config, null, new StringSerializer(Encoding.UTF8)))
        {
            for (int i = 0; i < 10; i++)
            {
                var dr = producer.ProduceAsync("my-replicated-topic3", null, i + ": **** some test message text *****").Result;
                Console.WriteLine($"Delivered '{dr.Value}' to: {dr.TopicPartitionOffset}");
            }
        }

        Console.ReadLine();
    }
}