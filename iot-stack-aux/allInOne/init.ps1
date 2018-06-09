invoke-webrequest -UseBasicparsing -Outfile cosmosdb-emulator.msi https://aka.ms/cosmosdb-emulator
Start-Process .\cosmosdb-emulator.msi -ArgumentList "/quiet" -Wait

invoke-webrequest -UseBasicparsing -Outfile docker_ce_win.exe https://download.docker.com/win/stable/Docker%20for%20Windows%20Installer.exe
Start-Process .\docker_ce_win.exe -ArgumentList "install --quiet" -Wait

# Use "-NoRestart" to avoid restart pop up.
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Hyper-V, Containers -All

$trigger = New-JobTrigger -AtStartup -RandomDelay 00:00:30
Register-ScheduledJob -Trigger $trigger -FilePath .\runEmulatorAndContainers.ps1 -Name EmulatorAndContainers

Restart-Computer -Force
