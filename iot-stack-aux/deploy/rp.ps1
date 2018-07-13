Connect-AzureRmAccount

$index = 6
$rgName = "iotrprg" + $index
$deploymentName = "iotrpdeploy" +  $index

New-AzureRmResourceGroup -Name $rgName -Location "eastus"

$namespaceName = "iotrpns"
$eventhubSku = "Standard"
$skuCapacity = 1
$eventHubName = "iotrp"
$consumerGroupName = "iotrpcg"

$dnsName = "iotstacksqlexdns2" + $index
$storageAccountName = "iotstacksqlexsa"  + $index
$adminUsername = "azureuser"
$pwd = "IotStackAux@1" | ConvertTo-SecureString -AsPlainText -Force
$vmName = "iotStackSqlExVm"
$templateBaseUrl = "https://raw.githubusercontent.com/yuekui2/azure-quickstart-templates/master/"

New-AzureRmResourceGroupDeployment `
    -Name $deploymentName `
    -ResourceGroupName $rgName `
    -TemplateFile C:\Users\kuiyu\kafkaAzure\azure-quickstart-templates\iot-stack-aux\rp\rp.json `
    -Verbose `
    -DeploymentDebugLogLevel All `
    -namespaceName $namespaceName `
    -eventhubSku $eventhubSku `
    -skuCapacity $skuCapacity `
    -eventHubName $eventHubName `
    -consumerGroupName $consumerGroupName `
    -sqlExNamespace iotStackSqlEx `
    -sqlExDnsName $dnsName `
    -sqlExStorageAccountName $storageAccountName `
    -sqlExVmName $vmName `
    -sqlExAdminUsername $adminUsername `
    -sqlExAdminPassword $pwd `
    -templateBaseUrl $templateBaseUrl

# Below are for individual ATM template testing out

$index = 4
$rgName = "iotrprg" + $index
$deploymentName = "iotrpdeploy" +  $index

New-AzureRmResourceGroup -Name $rgName -Location "eastus"

$namespaceName = "iotrpns"
$eventhubSku = "Standard"
$skuCapacity = 1
$eventHubName = "iotrp"
$consumerGroupName = "iotrpcg"

New-AzureRmResourceGroupDeployment `
    -Name $deploymentName -ResourceGroupName $rgName `
    -Verbose -DeploymentDebugLogLevel All `
    -namespaceName $namespaceName `
    -eventhubSku $eventhubSku `
    -skuCapacity $skuCapacity `
    -eventHubName $eventHubName `
    -consumerGroupName $consumerGroupName `
    -TemplateUri  https://raw.githubusercontent.com/yuekui2/azure-quickstart-templates/master/iot-stack-aux/rp/cluster.json

$dnsName = "iotstacksqlexdns2" + $index
$storageAccountName = "iotstacksqlexsa"  + $index
$adminUsername = "azureuser"
$pwd = "IotStackAux@1" | ConvertTo-SecureString -AsPlainText -Force
$vmName = "iotStackSqlExVm"
$templateBaseUrl = "https://raw.githubusercontent.com/yuekui2/azure-quickstart-templates/master/"

New-AzureRmResourceGroupDeployment `
    -Name $deploymentName `
    -ResourceGroupName $rgName `
    -TemplateFile C:\Users\kuiyu\kafkaAzure\azure-quickstart-templates\iot-stack-aux\rp\sqlExStack.json `
    -Verbose `
    -DeploymentDebugLogLevel All `
    -namespace iotStackSqlEx `
    -dnsName $dnsName `
    -storageAccountName $storageAccountName `
    -vmName $vmName `
    -adminUsername $adminUsername `
    -adminPassword $pwd `
    -templateBaseUrl $templateBaseUrl


