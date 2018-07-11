param([string]$username = "u", [string]$pwd = "p", [string]$computerName = "h")

$certsFolder = "certs"
$outputpath = "\\" + $computerName + "\" + $certsFolder + "\DocDbSslCert.pfx"
$pwd = ConvertTo-SecureString -String $pwd -Force -AsPlainText
Import-PfxCertificate -CertStoreLocation cert:\LocalMachine\Root -FilePath $outputpath -Password $pwd