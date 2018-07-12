param([string]$username = "u", [string]$pwd = "p", [string]$computerName = "c")

$certsFolder = "certs"
$outputpath = "\\" + $computerName + "\" + $certsFolder + "\DocDbSslCert.pfx"
copy $outputpath
$pwd = ConvertTo-SecureString -String $pwd -Force -AsPlainText
#Import-PfxCertificate -CertStoreLocation cert:\LocalMachine\Root -FilePath $outputpath -Password $pwd
Import-PfxCertificate -CertStoreLocation cert:\LocalMachine\Root -FilePath "DocDbSslCert.pfx" -Password $pwd