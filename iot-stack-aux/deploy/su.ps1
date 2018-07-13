Connect-AzureRmAccount

$index = 5
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
    -adminUsername $adminUsername `
    -adminPassword $pwd `
    -storageAccountName $storageAccountName `
    -storageEndpointSuffix "core.windows.net" `
    -templateBaseUrl $templateBaseUrl `
    -jumpBoxNewSubnetName $jumpBoxNewSubnetName `
    -jumpBoxNewSubnetAddressPrefix 10.0.6.0/24 `
    -jumpBoxVmName "jumpboxvm" `
    -jumpBoxNamespace $jumpBoxNamespace `
    -jumpBoxDnsName $jumpBoxDnsName `
    -docDbNewSubnetAddressPrefix "10.0.2.0/24" `
    -docDbNewVmPrivateIpAddress "10.0.2.10" `
    -docDbVmName "docDbVm" `
    -docDbVmSize "Standard_A3" `
    -docDBWindowsOSVersion "2016-Datacenter" `
    -tpNewSubnetName "tpsubnet" `
    -tpNewSubnetAddressPrefix "10.0.7.0/24" `
    -tpVmSize "Standard_A3" `
    -tpVmNames "tp0,tp3" `
    -tpVmIPs "10.0.7.10,10.0.7.13" `
    -tpTshirtSize "Test" `
    -mongoReplicaSetName "rs0" `
    -mongoReplicaSetKey "mongorskey" `
    -kafkaPartitions 16


New-AzureRmResourceGroupDeployment `
-Name $deploymentName `
-ResourceGroupName $rgName `
-TemplateFile C:\Users\kuiyu\kafkaAzure\azure-quickstart-templates\iot-stack-aux\shared\vnet\vnet.json `
-Verbose -DeploymentDebugLogLevel All `
-vnetName $vnetName `
-vnetAddrPrefix $vnetAddrPrefix

    Remove-AzurermVMCustomScriptExtension -ResourceGroupName $rgName -VMName jumpboxvm –Name scripts -Force

    New-AzureRmResourceGroupDeployment `
    -Name $deploymentName `
    -ResourceGroupName $rgName `
    -TemplateFile C:\Users\kuiyu\kafkaAzure\azure-quickstart-templates\iot-stack-aux\su\jumpboxWin1.json `
    -Verbose -DeploymentDebugLogLevel All `
    -vmName "jumpboxvm" `
    -adminUsername $adminUsername `
    -adminPassword $pwd `
    -docDbVmName "docDbVm" `
    -templateBaseUrl $templateBaseUrl

$newSubnetAddressPrefix = "10.0.7.0/24"
$newVmPrivateIpAddress = "10.0.7.10"
$vmSize = "Standard_A3"
$storageAccountName = "docdbsa" + $index + "n"
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


$newSubnetAddressPrefix = "10.0.7.0/24"
$vmSize = "Standard_A3"
$storageAccountName = "tpsa" + $index + "n"
New-AzureRmResourceGroupDeployment `
    -Name $deploymentName `
    -ResourceGroupName $rgName `
    -TemplateFile C:\Users\kuiyu\kafkaAzure\azure-quickstart-templates\iot-stack-aux\su\tp.json `
    -Verbose -DeploymentDebugLogLevel All `
    -existingVnetName $vnetName `
    -newSubnetName "auxsubset" `
    -newSubnetAddressPrefix $newSubnetAddressPrefix `
    -vmSize $vmSize `
    -adminUsername $adminUsername `
    -adminPassword $pwd `
    -storageAccountName $storageAccountName `
    -templateBaseUrl $templateBaseUrl `
    -vmNames "tp0,tp3" `
    -vmIPs "10.0.7.10,10.0.7.13"