param([string]$username = "u", [string]$pwd = "p")

$securePassword = $pwd | ConvertTo-SecureString -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential $username, $securePassword

invoke-webrequest -UseBasicparsing -Outfile cosmosdb-emulator.msi https://aka.ms/cosmosdb-emulator
Start-Process .\cosmosdb-emulator.msi -ArgumentList "/quiet" -Wait

invoke-webrequest -UseBasicparsing -Outfile docker_ce_win.exe https://download.docker.com/win/stable/Docker%20for%20Windows%20Installer.exe
Start-Process .\docker_ce_win.exe -ArgumentList "install --quiet" -Wait

# Use "-NoRestart" to avoid restart pop up.
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Hyper-V, Containers -All

#Import-Module ServerManager
#Add-WindowsFeature RSAT-AD-PowerShell
#import-module activedirectory
Add-LocalGroupMember -Group docker-users -Member $username

$action = {
    DO
    {
        sleep 5
        docker info
    } While ($LastExitCode -ne 0)

    docker stop iot-stack-redis
    docker rm iot-stack-redis
    docker rmi redis
    docker run --name iot-stack-redis -p 6379:6379 -d redis
}

$trigger = New-JobTrigger -AtStartup -RandomDelay 00:00:30
#Register-ScheduledJob -Trigger $trigger -FilePath .\runEmulatorAndContainers.ps1 -Name EmulatorAndContainers -Credential $credential
Register-ScheduledJob -Trigger $trigger -ScriptBlock $action -Name EmulatorAndContainers -Credential $credential

Restart-Computer -Force
