#& 'C:\Program Files\Azure Cosmos DB Emulator\CosmosDB.Emulator.exe'

DO
{
    sleep 5
    docker info
} While ($LastExitCode -ne 0)

docker stop iot-stack-redis
docker rm iot-stack-redis
docker rmi redis
docker run --name iot-stack-redis -p 6379:6379 -d redis

