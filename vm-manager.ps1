Write-Host "`nWelcome, this script allows you to start, stop and check status of multiple VMs in various resource groups in parallel." 

Write-Host "`nEnter action (start/stop/status):"

$Action = Read-Host

$VirtualMachinesDetails = Import-Csv .\VMLists.csv #Imports csv file from the specified path

if ($Action -eq "start"){

    Write-Host "Please specifiy the OS (Windows/Linux)"
    $OS_TYPE = Read-Host

    Write-Host "Please specifiy the environment (prod/dev)"

    $VM_Environment = Read-Host

    Write-Host "`nStarting all $OS_TYPE Virtual machines in the $VM_Environment environment..."

    $VirtualMachinesDetails | Where-Object {($_.VM_OS -eq $OS_TYPE) -and ($_.VM_Environment -eq $VM_Environment)} | ForEach-Object -parallel { #filters and fetches the csv files content based on the OS type.

        $checkIfVMExistInRG = get-azvm -ResourceGroupName $_.ResourceGroupName -name $_.VM_Name -ErrorVariable notPresent -ErrorAction SilentlyContinue # Checks if the VM exists in the RG

        if ($notPresent){
            continue
        }
        else {
            Start-AzVM -ResourceGroupName $_.ResourceGroupName -Name $_.VM_Name
        }
    } -ThrottleLimit 10

}
elseif ($Action -eq "stop"){

    Write-Host "Please specifiy the OS (Windows/Linux)"
    $OS_TYPE = Read-Host

    Write-Host "Please specifiy the environment (prod/dev):"

    $VM_Environment = Read-Host

    Write-Host "`nStopping all $OS_TYPE Virtual machines in the $VM_Environment environment..."

    $VirtualMachinesDetails | Where-Object {($_.VM_OS -eq $OS_TYPE) -and ($_.VM_Environment -eq $VM_Environment)} | ForEach-Object -parallel {

        $checkIfVMExistInRG = get-azvm -ResourceGroupName $_.ResourceGroupName -name $_.VM_Name -ErrorVariable notPresent -ErrorAction SilentlyContinue

        if ($notPresent){
            continue
        }
        else {
            Stop-AzVM -ResourceGroupName $_.ResourceGroupName -Name $_.VM_Name -Confirm:$false -ErrorAction SilentlyContinue -Force
        }
    } -ThrottleLimit 10
}

elseif($Action -eq "status"){

    Write-Host "Please specifiy the OS (windows/linux/all)"
    $OS_TYPE = "Windows"

    Write-Host "Please specifiy the environment (prod/dev/all)"
    $VM_Environment = "dev"

    Write-Host "`nGetting status of all $OS_TYPE Virtual machines in the $VM_Environment environment..."

    $Rg_Exist = @()
    $Vm_Exist = @()
    $vmStatuses = @()
    
    $VirtualMachinesDetails | Where-Object {($_.VM_OS -eq $OS_TYPE) -and ($_.VM_Environment -eq $VM_Environment)} | ForEach-Object {
        if ($Rg_Exist.Contains($_.ResourceGroupName) -and $Vm_Exist.Contains($_.VM_Name)) {
            return
        }
        else {
            
            $VMstatus = Get-AzVM -Name $_.VM_Name -ResourceGroupName $_.ResourceGroupName -Status
            $VMdetails = Get-AzVM -Name $_.VM_Name -ResourceGroupName $_.ResourceGroupName

            $vmInfo = [PSCustomObject]@{
                ResourceGroupName   = $vmStatus.ResourceGroupName
                Name                = $vmStatus.Name
                Location            = $VMdetails.Location
                VmSize              = $VMdetails.HardwareProfile.VmSize
                OsType              = $VMdetails.StorageProfile.OsDisk.OsType
                Disk_Status         = $vmStatus.Disks.Statuses.code
                VMAgentStatus       = $vmStatus.VMAgent.Statuses.DisplayStatus
                PowerState          = $vmStatus.Statuses[1].DisplayStatus     
                Provisioning        = $vmStatus.Statuses[0].DisplayStatus
                MaintenanceAllowed  = $vmStatus.MaintenanceRedeployStatus.IsCustomerInitiatedMaintenanceAllowed
            }
            $vmStatuses += $vmInfo

            $Rg_Exist += $_.ResourceGroupName
            $Vm_Exist += $_.VM_Name
        }        
    }
    $vmStatuses | Format-Table -AutoSize
}
else {
    Write-Host "action not recognized"
}
