﻿param (
    [parameter(Mandatory=$true)][string]$CsvFullPath,
    [string]$VMPath = "C:\VMs\"
)

$param = @("Name","Memory","ProcessorCount","Type")
if (!$VMPath.EndsWith('\')) {$VMPath = $VMPath.Insert($VMPath.Length,'\')}
cls
# Check if the csv file exists and try to import it
if (Get-Item $CsvFullPath -ErrorAction Ignore) {
    # Import Csv file
    try { $csvfile = Import-Csv $CsvFullPath -ErrorAction Stop} catch { Write-Warning "Csv file not found" }
    
    # Create a private switch if it does not exist
    if (-not(Get-VMSwitch -Name LAN -ErrorAction Ignore)) {
        New-VMSwitch -Name LAN -SwitchType Private
    }
    
    # For each machine in the csv file
    foreach ($item in $csvfile) {
        switch ($item.Type) {
            "Server" {$ISO = "C:\OS\Server2022.iso"; $SwitchName = "NATSwitch"}
            "Client" {$ISO = "C:\OS\Win10.iso"; $SwitchName = "LAN"}
        }
        try {
            # If VM with same name already exists throw an error
            if (Get-VM $item.Name -ErrorAction Ignore) {
                throw
            } else {
                New-VM -Name $item.Name -MemoryStartupBytes (($item.Memory).ToInt32($null)*1gb) -SwitchName $SwitchName -Path $VMPath `
                -NewVHDPath "$($VMPath+$item.Name+'\VHD\SYS.vhdx')" -NewVHDSizeBytes 127gb -Generation 2

                # Set Processor count, Dynamic RAM and disable automatic checkpoints
                Set-VM -Name $item.Name -ProcessorCount $item.ProcessorCount -DynamicMemory -AutomaticCheckpointsEnabled $false `
                -CheckpointType Standard
                # Set Memory Buffer% and priority
                Set-VMMemory -VMName $item.Name -Buffer 40 -Priority 65
                # Add a dvd drive with windows ISO mounted
                Add-VMDvdDrive -VMName $item.Name -ControllerNumber 0 -ControllerLocation 1 -Path $ISO

                # Set bootorder
                Set-VMFirmware -VMName $item.Name -BootOrder (Get-VMDvdDrive -VMName $item.Name), (Get-VMHardDiskDrive -VMName $item.Name)
            }
        } catch {
            Write-Warning "$('VM: '+$item.Name+', Already exists')"
        }
    }
} else {
    Write-Warning "Csv file not found"
}
