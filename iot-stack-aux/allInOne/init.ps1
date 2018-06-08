invoke-webrequest -UseBasicparsing -Outfile cosmosdb-emulator.msi https://aka.ms/cosmosdb-emulator
& .\cosmosdb-emulator.msi /quiet
& 'C:\Program Files\Azure Cosmos DB Emulator\CosmosDB.Emulator.exe'

invoke-webrequest -UseBasicparsing -Outfile docker_ce_win.exe https://download.docker.com/win/stable/Docker%20for%20Windows%20Installer.exe
& .\docker_ce_win.exe install --quiet

Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V, Containers -All

DO
{
    sleep 5
    docker info
} While ($LastExitCode -ne 0)

docker stop iot-stack-redis
docker rm iot-stack-redis
docker rmi redis
docker run --name iot-stack-redis -p 6379:6379 -d redis