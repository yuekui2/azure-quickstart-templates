$index = 7
$rgName = "iotrprg" + $index
$deploymentName = "iotrpdeploy" +  $index
$vnetName = "stackvnet" + $index
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
    -jumpBoxNewSubnetName $jumpBoxNewSubnetName `
    -jumpBoxNewSubnetAddressPrefix 10.0.6.0/24 `
    -storageAccountName $storageAccountName `
    -jumpBoxVmName $vmNamePrefix `
    -adminUsername $adminUsername `
    -adminPassword $pwd `
    -jumpBoxNamespace $jumpBoxNamespace `
    -jumpBoxDnsName $jumpBoxDnsName `
    -templateBaseUrl $templateBaseUrl


