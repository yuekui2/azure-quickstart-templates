Connect-AzureRmAccount

$index = 3
[int]$vmCount = 6
$templateBaseUrl = "https://raw.githubusercontent.com/yuekui2/azure-quickstart-templates/master/"

$rgName = "kuistackrg" + $index
$deploymentName = "kuistackrgdeploy" +  $index
$vnetName = "stackvnet" + $index
$storageAccountName = "stackauxsab" + $index
$vmNamePrefix = "auxvm" + $index

$adminUsername="azureuser"
$PlainPassword = "IotStackAux@1"
$pwd = $PlainPassword | ConvertTo-SecureString -AsPlainText -Force

$vnetAddrPrefix = "10.0.0.0/16"
$vmSubnetAddrPrefix = "10.0.1.0/24"
$newVmPrivateIpAddressPrefix = "10.0.1.1"

$jumpboxLinuxSubnetAddrPrefix = "10.0.2.0/24"
$jumpboxWindowsSubnetAddrPrefix = "10.0.3.0/24"

New-AzureRmResourceGroup -Name $rgName -Location "eastus"

# vnet
New-AzureRmResourceGroupDeployment `
    -Name $deploymentName -ResourceGroupName $rgName `
    -Verbose -DeploymentDebugLogLevel All `
    -vnetName $vnetName `
    -vnetAddrPrefix $vnetAddrPrefix `
    -TemplateUri  https://raw.githubusercontent.com/yuekui2/azure-quickstart-templates/master/iot-stack-aux/shared/vnet/vnet.json


# vm in a new subnet
$newSubnetName = "auxsubnet" + $index
$namespace = "aux"  + $index
$vmSize = "Standard_A1"
New-AzureRmResourceGroupDeployment `
    -Name $deploymentName -ResourceGroupName $rgName `
    -Verbose -DeploymentDebugLogLevel All `
    -templateBaseUrl $templateBaseUrl `
    -existingVnetName $vnetName `
    -newSubnetName $newSubnetName `
    -newSubnetAddressPrefix $vmSubnetAddrPrefix `
    -storageAccountName $storageAccountName `
    -newVmPrivateIpAddressPrefix $newVmPrivateIpAddressPrefix `
    -vmNamePrefix $vmNamePrefix `
    -vmCount $vmCount `
    -vmSize $vmSize `
    -adminUsername $adminUsername -adminPassword $pwd `
    -namespace $namespace `
    -TemplateFile C:\Users\kuiyu\kafkaAzure\azure-quickstart-templates\iot-stack-aux\shared\vm\vm.json


# windows jumpbox
$newSubnetName = "jumpboxsubnetw" + $index
$namespace = "jumpboxw"  + $index
$dnsName = "jumpboxdnsw" + $index
$vmNamePrefix = "auxvmw" + $index
New-AzureRmResourceGroupDeployment `
    -Name $deploymentName -ResourceGroupName $rgName -Verbose -DeploymentDebugLogLevel All `
    -templateBaseUrl $templateBaseUrl `
    -TemplateFile C:\Users\kuiyu\kafkaAzure\azure-quickstart-templates\iot-stack-aux\shared\vm\jumpboxWin.json `
    -existingVnetName $vnetName `
    -newSubnetName $newSubnetName `
    -newSubnetAddressPrefix $jumpboxWindowsSubnetAddrPrefix `
    -dnsName $dnsName `
    -storageAccountName $storageAccountName `
    -vmNamePrefix $vmNamePrefix `
    -adminUsername $adminUsername -adminPassword $pwd `
    -namespace $namespace

# linux jumpbox
$newSubnetName = "jumpboxsubnet" + $index
$namespace = "jumpbox"  + $index
$dnsName = "jumpboxdns" + $index
$vmNamePrefix = "auxvm" + $index
New-AzureRmResourceGroupDeployment `
    -Name $deploymentName -ResourceGroupName $rgName -Verbose -DeploymentDebugLogLevel All `
    -templateBaseUrl $templateBaseUrl `
    -TemplateFile C:\Users\kuiyu\kafkaAzure\azure-quickstart-templates\iot-stack-aux\shared\vm\jumpbox.json `
    -existingVnetName $vnetName `
    -newSubnetName $newSubnetName `
    -newSubnetAddressPrefix $jumpboxLinuxSubnetAddrPrefix `
    -dnsName $dnsName `
    -storageAccountName $storageAccountName `
    -vmNamePrefix $vmNamePrefix `
    -adminUsername $adminUsername -adminPassword $pwd `
    -namespace $namespace

$vmNameArr = @()
$vmIpArr = @()
for ($i = 0; $i -lt $vmCount; $i++) {
    $vmNameArr += @($vmNamePrefix + $i)
    $vmIpArr += @($newVmPrivateIpAddressPrefix + $i)
}

$vmNames = $vmNameArr -join ','
$vmIPs = $vmIpArr -join ','
$tshirtSize = "Test"

Write-Host($vmNames)
Write-Host($vmIPs)

# Workaround for only custom script per virtual machine is supported.
# https://blogs.technet.microsoft.com/meamcs/2016/01/30/run-two-powershell-scripts-on-a-same-vm-through-custom-script-extension-at-different-stage-of-deployment-in-arm/
$scriptName = "mountdisk"
For ($i = 0; $i -lt $vmCount; $i++) {
    $vmName = $vmNamePrefix + $i
    Write-Host $vmName
    Remove-AzurermVMCustomScriptExtension -ResourceGroupName $rgName -VMName $vmName –Name $scriptName -Force
}

$replicaSetName="rs0"
$replicaSetKey="replicask"
New-AzureRmResourceGroupDeployment `
    -Name $deploymentName -ResourceGroupName $rgName `
    -Verbose -DeploymentDebugLogLevel All `
    -vmNames $vmNames `
    -vmIPs $vmIPs `
    -templateBaseUrl $templateBaseUrl `
    -tshirtSize $tshirtSize `
    -adminUsername $adminUsername -adminPassword $pwd `
    -replicaSetName $replicaSetName -replicaSetKey $replicaSetKey `
    -TemplateFile C:\Users\kuiyu\kafkaAzure\azure-quickstart-templates\iot-stack-aux\oneScript\extension.json

$scriptName = "scripts"
For ($i = 0; $i -lt $vmCount; $i++) {
    $vmName = $vmNamePrefix + $i
    Write-Host $vmName
    Remove-AzurermVMCustomScriptExtension -ResourceGroupName $rgName -VMName $vmName –Name $scriptName -Force
}