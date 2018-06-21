using System;

namespace RedisConnection
{
    class Program
    {
        static void Main(string[] args)
        {
            var redis = RedisStore.RedisCache;
            string key = "testKey";
            string val = "testValue";
            bool existing = redis.KeyDelete(key);

            if (existing)
            {
                Console.WriteLine("Delete key \"{0}\" successfully", key);
            }

            if (redis.StringSet(key, val))
            {
                Console.WriteLine("Set key \"{0}\" to \"{1}\" successfully", key, val);

                var val2 = redis.StringGet(key);

                Console.WriteLine("Get key \"{0}\" with value \"{1}\" successfully", key, val2);
            } else
            {
                Console.WriteLine("Failed to set key  \"{0}\"", key);
            }

            //Console.ReadKey();
        }
    }
}
