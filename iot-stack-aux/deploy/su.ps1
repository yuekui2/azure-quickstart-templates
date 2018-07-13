Connect-AzureRmAccount

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
$tpStorageAccountName = "tpsa" + $index
$vmNamePrefix = "auxvm" + $index

New-AzureRmResourceGroup -Name $rgName -Location "eastus"

$jumpBoxNewSubnetName = "jumpboxwsubnet" + $index
$jumpBoxNamespace = "jumpboxw"  + $index
$jumpBoxDnsName = "jumpboxwdns" + $index
$vmNamePrefix = "auxvmw" + $index
$jumpBoxVmName = "jumpboxvm" + $index
$docDbVmName = "docDbVm" + $index
$tpNewSubnetName = "tpsubnet" + $index

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
    -jumpBoxVmName $jumpBoxVmName `
    -jumpBoxNamespace $jumpBoxNamespace `
    -jumpBoxDnsName $jumpBoxDnsName `
    -docDbNewSubnetAddressPrefix "10.0.2.0/24" `
    -docDbNewVmPrivateIpAddress "10.0.2.10" `
    -docDbVmName $docDbVmName `
    -docDbVmSize "Standard_A3" `
    -docDBWindowsOSVersion "2016-Datacenter" `
    -tpNewSubnetName $tpNewSubnetName `
    -tpNewSubnetAddressPrefix "10.0.7.0/24" `
    -tpVmSize "Standard_A3" `
    -tpVmNames "tp1,tp2,tp3" `
    -tpVmIPs "10.0.7.11,10.0.7.12,10.0.7.13" `
    -tpStorageAccountName $tpStorageAccountName `
    -tpTshirtSize "Test" `
    -mongoReplicaSetName "rs0" `
    -mongoReplicaSetKey "mongorskey" `
    -kafkaPartitions 16

    Remove-AzurermVMCustomScriptExtension -ResourceGroupName $rgName -VMName jumpboxvm –Name scripts -Force

New-AzureRmResourceGroupDeployment `
-Name $deploymentName `
-ResourceGroupName $rgName `
-TemplateFile C:\Users\kuiyu\kafkaAzure\azure-quickstart-templates\iot-stack-aux\shared\vnet\vnet.json `
-Verbose -DeploymentDebugLogLevel All `
-vnetName $vnetName `
-vnetAddrPrefix $vnetAddrPrefix



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
    -vmNames "tp1,tp2,tp3" `
    -vmIPs "10.0.7.11,10.0.7.12,10.0.7.13"