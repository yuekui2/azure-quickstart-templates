# Initialize datadisk
Get-Disk | `
Where partitionstyle -eq 'raw' | `
Initialize-Disk -PartitionStyle MBR -PassThru | `
New-Partition -AssignDriveLetter -UseMaximumSize | `
Format-Volume -FileSystem NTFS -NewFileSystemLabel "datadisk" -Confirm:$false

# Create database folders
$dataPath = "F:\SQL5\Data"
$logPath = "F:\SQL5\Logs"
$paths = $dataPath, $logPath
Foreach ($path in $paths)
{
    If(!(test-path $path))
    {
          New-Item -ItemType Directory -Force -Path $path
    }
}

# Change default database file location
& sqlcmd -i "setDB.sql" -o "output.txt"

# Restart to  make it effective
Restart-Service -Force MSSQLSERVER

& sqlcmd -i "createTestDB.sql" -o "output2.txt"
