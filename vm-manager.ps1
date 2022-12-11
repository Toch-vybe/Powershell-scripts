Write-Host "`nWelcome, this script allows you to start, stop and check status of multiple VMs in various resource groups in parallel. `n" 

Write-Host "`nEnter action (start/stop/status):"

$Action = Read-Host

$VirtualMachinesDetails = Import-Csv .\VMLists.csv #Imports csv file from the specified path

if ($Action -eq "start"){

    $OS_TYPE = "Windows"

    Write-Host "Please specifiy the environment (Prod/Dev/Test)"

    $VM_Environment = Read-Host

    Write-Host "`nStarting all $OS_TYPE Virtual machines in the $VM_Environment environment..."

    $VirtualMachinesDetails | Where-Object {$_.VM_OS -eq $OS_TYPE -and $_.VM_Environment -eq $VM_Environment} | ForEach-Object -parallel { #filters and fetches the csv files content based on the OS type.

        $checkIfVMExistInRG = get-azvm -ResourceGroupName $_.VM_RG -name $_.VM_Name -ErrorVariable notPresent -ErrorAction SilentlyContinue # Checks if the VM exists in the RG

        if ($notPresent){
            continue
        }
        else {
            Start-AzVM -ResourceGroupName $_.VM_RG -Name $_.VM_Name
        }
    } -ThrottleLimit 10

}
elseif ($Action -eq "stop"){

    $OS_TYPE = "Windows"

    Write-Host "Please specifiy the environment (Prod/Dev/Test)"

    $VM_Environment = Read-Host

    Write-Host "`nStopping all $OS_TYPE Virtual machines in the $VM_Environment..."

    $VirtualMachinesDetails | Where-Object {$_.VM_OS -eq $OS_TYPE -and $_.VM_Environment -eq $VM_Environment} | ForEach-Object -parallel {

        $checkIfVMExistInRG = get-azvm -ResourceGroupName $_.VM_RG -name $_.VM_Name -ErrorVariable notPresent -ErrorAction SilentlyContinue

        if ($notPresent){
            continue
        }
        else {
            Stop-AzVM -ResourceGroupName $_.VM_RG -Name $_.VM_Name -Confirm:$false -ErrorAction SilentlyContinue -Force
        }
    } -ThrottleLimit 10
}

elseif($Action -eq "status"){

    $OS_TYPE = "Windows"

    Write-Host "Please specifiy the environment (Prod/Dev/Test)"

    $VM_Environment = Read-Host

    Write-Host "`nGetting status of all $OS_TYPE Virtual machines in the $VM_Environment environment..."

    $Rg_Exist = @()
    $VirtualMachinesDetails | Where-Object {$_.VM_OS -eq $OS_TYPE} | ForEach-Object {
      
        if ($Rg_Exist.Contains($_.VM_RG)) {
            return
        }
        else {
            Get-AzVM -ResourceGroupName $_.VM_RG -Status
            $Rg_Exist += $_.VM_RG
        }        
    }


 }
else {
    Write-Host "action not recognized"
}
