param([string]$username = "u", [string]$pwd = "p", [string]$computerName = "c")

$securePassword = $pwd | ConvertTo-SecureString -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential $username, $securePassword

$certsFolder = "certs"
$outputpath = "\\" + $computerName + "\" + $certsFolder + "\DocDbSslCert.pfx"
copy $outputpath -Credential $credential
$pwd = ConvertTo-SecureString -String $pwd -Force -AsPlainText
#Import-PfxCertificate -CertStoreLocation cert:\LocalMachine\Root -FilePath $outputpath -Password $pwd
Import-PfxCertificate -CertStoreLocation cert:\LocalMachine\Root -FilePath "DocDbSslCert.pfx" -Password $pwd