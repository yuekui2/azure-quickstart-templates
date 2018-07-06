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

# Change default database file location
& sqlcmd -i "setup.sql" -o "output.txt"

# Restart to make it effective
Restart-Service -Force MSSQLSERVER

# Create a test DB
& sqlcmd -i "createTestDB.sql" -o "output.txt"
# Enable and create SQL server login.
& sqlcmd -v UserName=$username -v Password=$pwd -i "CreateSqlLogins.sql" -o "output.txt"
# Create tables for IOT hub
& sqlcmd -i "CreateIotHubProvisioningSchema.sql" -o "output.txt"
& sqlcmd -i "CreateIotHubProvisioningLogic.sql" -o "output.txt"
& sqlcmd -i "CreateIotHubProvisioningVersionData.sql" -o "output.txt"
& sqlcmd -i "CreateIotHubProvisioningData.sql" -o "output.txt"
& sqlcmd -i "IotDpsProvisioningSchema.sql" -o "output.txt"
& sqlcmd -i "IotDpsProvisioningLogic.sql" -o "output.txt"