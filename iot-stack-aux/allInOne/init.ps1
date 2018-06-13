param([string]$username = "u", [string]$pwd = "p")

$securePassword = $pwd | ConvertTo-SecureString -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential $username, $securePassword

invoke-webrequest -UseBasicparsing -Outfile cosmosdb-emulator.msi https://aka.ms/cosmosdb-emulator -Credential $credential
Start-Process .\cosmosdb-emulator.msi -ArgumentList "/quiet" -Wait

invoke-webrequest -UseBasicparsing -Outfile docker_ce_win.exe https://download.docker.com/win/stable/Docker%20for%20Windows%20Installer.exe -Credential $credential
Start-Process .\docker_ce_win.exe -ArgumentList "install --quiet" -Wait

# Use "-NoRestart" to avoid restart pop up.
Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Hyper-V, Containers -All

Add-LocalGroupMember -Group docker-users -Member $username

$action = {
    Start-Process 'C:\Program Files\Azure Cosmos DB Emulator\CosmosDB.Emulator.exe' -ArgumentList "/NoUI"
    Start-Process 'C:\Program Files\Docker\Docker\Docker for Windows.exe'

    DO
    {
        sleep 5
        docker info
    } While ($LastExitCode -ne 0)

    docker stop iot-stack-redis
    docker rm iot-stack-redis
    docker rmi redis
    docker run --name iot-stack-redis -p 6379:6379 -d redis

    docker run -d -p 8080:8080 trinitronx/python-simplehttpserver
}

function Retry-Command {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Position=1, Mandatory=$false)]
        [int]$Maximum = 5
    )

    Begin {
        $cnt = 0
    }

    Process {
        do {
            $cnt++
            $cnt >> 'jobScheduleLog.txt'
            try {
                sleep 5
                $ScriptBlock.Invoke()

                return
            } catch {
                Write-Error $_.Exception.InnerException.Message -ErrorAction Continue
            }
        } while ($cnt -lt $Maximum)

        # Throw an error after $Maximum unsuccessful invocations. Doesn't need
        # a condition, since the function returns upon successful invocation.
        throw 'Execution failed.'
    }
}

Retry-Command {
    $username >> 'jobScheduleLog.txt'
    $pwd >> 'jobScheduleLog.txt'
    Get-LocalGroupMember -Group "Administrators" >> 'jobScheduleLog.txt'
    $trigger = New-JobTrigger -AtStartup -RandomDelay 00:00:30
    Register-ScheduledJob -Trigger $trigger -ScriptBlock $action -Name EmulatorAndContainers -Credential $credential -ErrorAction Stop
} -Maximum 20

New-NetFirewallRule -DisplayName "Allow http 8080" -Direction Inbound -Protocol TCP -LocalPort 8080

New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name AutoAdminLogon -Value 1
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name DefaultUserName -Value $username
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name DefaultPassword -Value $pwd

Restart-Computer -Force
