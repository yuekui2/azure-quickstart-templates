param([string]$username = "u", [string]$pwd = "p", [string]$computerName = "c")

$certsFolder = "certs"
$outputpath = "\\" + $computerName + "\" + $certsFolder + "\DocDbSslCert.pfx"

$cnt = 0
$ret = $false
DO {
    Write-Host $cnt
    sleep 5
    $cnt++
    $ret = [System.IO.File]::Exists($outputpath)
} While (($cnt -lt 5) -and (!$ret))

$pwd = ConvertTo-SecureString -String $pwd -Force -AsPlainText
Import-PfxCertificate -CertStoreLocation cert:\LocalMachine\Root -FilePath $outputpath -Password $pwd