param([string]$username = "u", [string]$pwd = "p")

invoke-webrequest -UseBasicparsing -Outfile cosmosdb-emulator.msi https://aka.ms/cosmosdb-emulator
Start-Process .\cosmosdb-emulator.msi -ArgumentList "/quiet" -Wait
Start-Process 'C:\Program Files\Azure Cosmos DB Emulator\CosmosDB.Emulator.exe' -ArgumentList "/NoUI /AllowNetworkAccess /Key=lf2YxcQQS1etfXeEsxFavN7k4isJOjOC+wnJuUbZnvBUzMe7GsHg5SQXTI8nQyTXkM3i2eJOCE3nFvP7N//2CQ== /Consistency=Strong /PartitionCount=100"

# Open firewall
New-NetFirewallRule -DisplayName "Allow http 10251" -Direction Inbound -Protocol TCP -LocalPort 10251
New-NetFirewallRule -DisplayName "Allow http 10252" -Direction Inbound -Protocol TCP -LocalPort 10252
New-NetFirewallRule -DisplayName "Allow http 10253" -Direction Inbound -Protocol TCP -LocalPort 10253
New-NetFirewallRule -DisplayName "Allow http 10254" -Direction Inbound -Protocol TCP -LocalPort 10254
New-NetFirewallRule -DisplayName "Allow http 8081" -Direction Inbound -Protocol TCP -LocalPort 8081

$computerName = (get-childitem -path env:computername).Value
$certsFolder = "certs"
New-FileShare -Name $certsFolder -SourceVolume (Get-Volume -DriveLetter C) -FileServerFriendlyName $computerName
Get-FileShare -Name $certsFolder | Grant-FileShareAccess -AccountName Everyone -AccessRight Full

# Export document DB emulator cert
$DocDbSslCert = Get-ChildItem -Path cert:\LocalMachine\My | Where-Object {$_.FriendlyName -eq 'DocumentDbEmulatorCertificate' }
$pwd = ConvertTo-SecureString -String $pwd -Force -AsPlainText
$certpath = "cert:\localMachine\my\" + $DocDbSslCert.Thumbprint
$outputpath = "\\" + $computerName + "\" + $certsFolder + "\DocDbSslCert.pfx"
Export-PfxCertificate -cert $certpath -FilePath $outputpath -Password $pwd