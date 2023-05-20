# Install required module if not already installed
Install-Module -Name Az.Billing -Force
Install-Module -Name ImportExcel -Force

# Connect to Azure
Connect-AzAccount

# Set subscription context
Set-AzContext -SubscriptionId "YourSubscriptionId"

Write-Host "`nWelcome, this script runs daily to check your cost usage on you Azure VM and append the result to an Excel Sheet. `n" 

#This line below imports a csv file, this script assumes the script is in a storage account on Azure, modify the path to your liking.
#This file shouls have at least a column for the VM name and the Resource group.
$VirtualMachinesDetails = Import-Csv .\VMLists.csv 

#Looping through each VM
foreach ($VirtualMachinesDetail in $VirtualMachinesDetails){

    #Retrieve the VM
    $vm = Get-AzVM -name $_.VM_Name -ResourceGroupName $_.VM_RG

    #Duration of usage, 24 hours ago
    $start_date = (Get-Date).AddHours(-24)
    $end_date = Get-Date #current date

    #Get the cost of a VM
    $costs = Get-AzConsumptionUsageDetail -MeterID "Compute Hours"-DimensionName "Resource Name" DimensionValue $vm.Name -StartTime $start_date -EndTime $end_date
    $total_costs = $costs | Measure-Object -Property PretaxCost -Sum | Select-Object -ExpandProperty -Sum

    #This section Export and append to an Excel sheet in your storage account

    # Azure Blob Storage details
    $storageAccountName = "YourStorageAccountName"
    $containerName = "YourContainerName"
    $blobName = "cost_details.xlsx"

    # Create a reference to the existing Excel file in Azure Blob Storage
    $context = New-AzStorageContext -StorageAccountName $storageAccountName -UseConnectedAccount
    $blobClient = $context.StorageAccount.CreateCloudBlobClient()
    $container = $blobClient.GetContainerReference($containerName)
    $blob = $container.GetBlockBlobReference($blobName)

    # Download the existing Excel file as a stream
    $excelStream = [System.IO.MemoryStream]::new()
    $blob.DownloadToStream($excelStream)

    # Import existing data from the Excel file
    $existingData = Import-Excel -Path $excelStream -WorksheetName "Cost Details"

    # Append cost details to existing data
    $updatedData = $existingData + $total_costs

    # Export cost details to a new Excel file stream
    $newExcelStream = Export-Excel -InputObject $updatedData -WorksheetName "Cost Details"

    # Upload the updated Excel file stream to Azure Blob Storage
    $blob.UploadFromStream($newExcelStream)

    Write-Host "Cost details appended and saved to Azure Blob Storage: $blobName"


}