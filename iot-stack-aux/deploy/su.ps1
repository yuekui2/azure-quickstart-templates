$index = 1
$rgName = "iotrprg" + $index
$deploymentName = "iotrpdeploy" +  $index
$vnetName = "stackvnet" + $index
$vnetAddrPrefix = "10.0.0.0/16"
$adminUsername="azureuser"
$PlainPassword = "IotStackAux@1"
$pwd = $PlainPassword | ConvertTo-SecureString -AsPlainText -Force
$templateBaseUrl = "https://raw.githubusercontent.com/yuekui2/azure-quickstart-templates/master/"
$storageAccountName = "stackauxsab" + $index
$vmNamePrefix = "auxvm" + $index

New-AzureRmResourceGroup -Name $rgName -Location "eastus"

$jumpBoxNewSubnetName = "jumpboxwsubnet" + $index
$jumpBoxNamespace = "jumpboxw"  + $index
$jumpBoxDnsName = "jumpboxwdns" + $index
$vmNamePrefix = "auxvmw" + $index

New-AzureRmResourceGroupDeployment `
    -Name $deploymentName `
    -ResourceGroupName $rgName `
    -TemplateFile C:\Users\kuiyu\kafkaAzure\azure-quickstart-templates\iot-stack-aux\su\su.json `
    -Verbose -DeploymentDebugLogLevel All `
    -vnetName $vnetName `
    -vnetAddrPrefix $vnetAddrPrefix `
    -jumpBoxNewSubnetName $jumpBoxNewSubnetName `
    -jumpBoxNewSubnetAddressPrefix 10.0.6.0/24 `
    -storageAccountName $storageAccountName `
    -jumpBoxVmName $vmNamePrefix `
    -adminUsername $adminUsername `
    -adminPassword $pwd `
    -jumpBoxNamespace $jumpBoxNamespace `
    -jumpBoxDnsName $jumpBoxDnsName `
    -templateBaseUrl $templateBaseUrl

$newSubnetAddressPrefix = "10.0.7.0/24"
$newVmPrivateIpAddress = "10.0.7.10"
$vmSize = "Standard_A3"
$storageAccountName = "docdbsa"
New-AzureRmResourceGroupDeployment `
    -Name $deploymentName `
    -ResourceGroupName $rgName `
    -TemplateFile C:\Users\kuiyu\kafkaAzure\azure-quickstart-templates\iot-stack-aux\su\docDb.json `
    -Verbose -DeploymentDebugLogLevel All `
    -existingVnetName $vnetName `
    -newSubnetAddressPrefix $newSubnetAddressPrefix `
    -newVmPrivateIpAddress $newVmPrivateIpAddress `
    -vmSize $vmSize `
    -adminUsername $adminUsername `
    -adminPassword $pwd `
    -windowsOSVersion 2016-Datacenter `
    -storageAccountName $storageAccountName `
    -templateBaseUrl $templateBaseUrl

