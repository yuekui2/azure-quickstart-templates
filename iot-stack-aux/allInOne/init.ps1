invoke-webrequest -UseBasicparsing -Outfile cosmosdb-emulator.msi https://aka.ms/cosmosdb-emulator
Start-Process .\cosmosdb-emulator.msi -ArgumentList "/quiet" -Wait
& 'C:\Program Files\Azure Cosmos DB Emulator\CosmosDB.Emulator.exe'

invoke-webrequest -UseBasicparsing -Outfile docker_ce_win.exe https://download.docker.com/win/stable/Docker%20for%20Windows%20Installer.exe
& .\docker_ce_win.exe install --quiet

# Use "-NoRestart" to avoid restart pop up.
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Hyper-V, Containers -All
Restart-Computer
