param([string]$username = "u", [string]$pwd = "p")

# Initialize datadisk
Get-Disk | `
Where partitionstyle -eq 'raw' | `
Initialize-Disk -PartitionStyle MBR -PassThru | `
New-Partition -AssignDriveLetter -UseMaximumSize | `
Format-Volume -FileSystem NTFS -NewFileSystemLabel "datadisk" -Confirm:$false

# Create database folders
$dataPath = "F:\SQL\Data"
$logPath = "F:\SQL\Logs"
$backupPath = "F:\SQL\Backups"
$paths = $dataPath, $logPath, $backupPath
Foreach ($path in $paths)
{
    If(!(test-path $path))
    {
          New-Item -ItemType Directory -Force -Path $path
    }
}

# Open firewall for sql server port
New-NetFirewallRule -DisplayName "Allow http 1433" -Direction Inbound -Protocol TCP -LocalPort 1433

# Change default database file location
& sqlcmd -i "setup.sql" -o "output1.txt"

# Restart to make it effective
Restart-Service -Force MSSQLSERVER

# Create a test DB
& sqlcmd -i "createTestDB.sql" -o "output2.txt"
# Enable and create SQL server login.
& sqlcmd -v UserName=$username -v Password=$pwd -i "CreateSqlLogins.sql" -o "output3.txt"
# Create tables for IOT hub
& sqlcmd -i "CreateIotHubProvisioningSchema.sql" -o "output4.txt"
& sqlcmd -i "CreateIotHubProvisioningLogic.sql" -o "output5.txt"
& sqlcmd -i "CreateIotHubProvisioningVersionData.sql" -o "output6.txt"
& sqlcmd -i "CreateIotHubProvisioningData.sql" -o "output7.txt"
& sqlcmd -i "IotDpsProvisioningSchema.sql" -o "output8.txt"
& sqlcmd -i "IotDpsProvisioningLogic.sql" -o "output9.txt"