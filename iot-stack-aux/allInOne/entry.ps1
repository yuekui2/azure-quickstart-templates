param([string]$username = "u", [string]$pwd = "p")

$securePassword = $pwd | ConvertTo-SecureString -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential $username, $securePassword

Start-Process powershell.exe -ArgumentLis "-ExecutionPolicy Unrestricted -file .\init.ps1" -Credential $credential
