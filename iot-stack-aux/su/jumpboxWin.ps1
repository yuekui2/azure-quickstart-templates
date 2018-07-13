param([string]$username = "u", [string]$pwd = "p", [string]$computerName = "c")

$certsFolder = "certs"
$remotepath = "\\" + $computerName + "\" + $certsFolder
net use $remotepath $pwd /USER:$username

$remotefile =  $remotepath + "\DocDbSslCert.pfx"
copy $remotefile

$pwd = ConvertTo-SecureString -String $pwd -Force -AsPlainText
#Import-PfxCertificate -CertStoreLocation cert:\LocalMachine\Root -FilePath $outputpath -Password $pwd
Import-PfxCertificate -CertStoreLocation cert:\LocalMachine\Root -FilePath "DocDbSslCert.pfx" -Password $pwd