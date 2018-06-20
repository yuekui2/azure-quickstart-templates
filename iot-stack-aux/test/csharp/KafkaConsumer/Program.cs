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
        var conf = new Dictionary<string, object>
    {
      { "group.id", "test-consumer-group" },
      { "bootstrap.servers",   ConfigurationManager.AppSettings["kafka.connection"]},
      { "auto.commit.interval.ms", 5000 },
      { "auto.offset.reset", "earliest" }
    };

        using (var consumer = new Consumer<Null, string>(conf, null, new StringDeserializer(Encoding.UTF8)))
        {
            consumer.OnMessage += (_, msg)
              => Console.WriteLine($"Read '{msg.Value}' from: {msg.TopicPartitionOffset} -- {msg.Partition}");

            consumer.OnError += (_, error)
              => Console.WriteLine($"Error: {error}");

            consumer.OnConsumeError += (_, msg)
              => Console.WriteLine($"Consume error ({msg.TopicPartitionOffset}): {msg.Error}");

            consumer.Subscribe("my-replicated-topic3");

            while (true)
            {
                consumer.Poll(TimeSpan.FromMilliseconds(100));
            }
        }
    }
}
