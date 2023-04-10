#Date: 08.08.2021
#Tested on: MacOS BigSUR 11.3; PowerShell Ver: 7.13

<##
The script can be written in PowerShell or Azure CLI or any other language you prefer.
In this exercise, you will be asked to create two virtual machines (in parallel) - all the steps should be done from interactive script written in PowerShell and/or Azure CLI as mentioned above.

Few requirements:

•	All resources should be created in the existing resource group you have an access to.
•	All resources should be created in “North Europe” region

Please save the code you write and attach it once you finish the test - You can use either Azure Cloud Shell or your own workstation.

The script should contain the following:

1.	Prompt for name prefix for each machine and number of machines you would like to create
Example: testvm => machines will be named as testvm-1, testvm-2, etc..

2.	Create X number of virtual machines (in parallel) with public static IPs 
                A. Max number of machines should be limited to 4 
                B. Tags:
                                I. If you provided an even number (2 or 4) Half of the machines should be created with "shutdown" tag and contain only one disk (OS Disk)
                                II. If you provided an uneven number, created machines should be created with two disks (OS Disk and Data Disk)
                                Note: Keep in mind that the logic should not be hardcoded to 1-4 machines, but suppose to work for higher number as well

                C. Number of machines should be the specified parameter from step 1 - the creation should be done in parallel
                D. Virtual network should contain the specified name for the name specified in step 1 for instance (for example: “testvm-vnet”)
                E. The script should handle exceptions which should be written to a log file.
                F. Public IPs should contain the specified name prefix from step 1, for instance testvm-1-pip

3.	Once machines were created, print the name of each created machine
4.	[Optional] - Print the public IPs (PIP) of each machine
Once the script was executed ,try to RDP to each machine - if you skipped step 5, you can find the public IPs from the portal 

5.	Write additional (small) script which shut down all machines with the 'shutdown' tag

#>

#Solution

#Prerequesites 
#Azure module - Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force

#For part number 5, just run the script with -shutdown argument
#Running this script from trial azure account limit my depolyment to max of 2 instances
#This script havent been tested for more than 2 instances

#Configuration Part
$MAX_NUM_OF_VM=4 #Maximum number for user to deploy VM's
$LOG_FILE='/users/shaharweiss/azure.log'
$JOBSNAME = 'HomeWork'#Parallel jobs name, jobs will be HomeWork1, HomeWork2 ...
$ResourceGroup='HomeWork'
$LOCATION='northeurope'
$DiskSize=5#Disk size in GB for Extra Drive
#part of username pass for vm

$DEFAULTADMIN='HomeWork01'#Vm's Default Admin username & password, please be sure to change it after deoplyment
$DEFAULTPASS='D0ntF0rgetToChaneIT!'

[securestring]$secStringPassword = ConvertTo-SecureString $DEFAULTPASS -AsPlainText -Force
[pscredential]$cred = New-Object System.Management.Automation.PSCredential ($DEFAULTADMIN, $secStringPassword)

#End of configuration part

#Functions part

function Log ([string] $content){#Log string into file 
    $Date=Get-Date
Add-Content -Path $LOG_FILE -Value ("$date : $content") 

}

function Chk_if_num_is_even ([int] $number){#Return true if number is even
    return ($number % 2 -eq 0 )
}
function Verify_Deploy ([int] $Num_Of_VMs, [string] $rg){#Will return current VM's Deployed == Vm requested
    return ((Get-AzVM -ResourceGroupName $rg).count -eq $Num_Of_VMs)
}

$Scope_Wait_for_Jobs= {#This function is encapsulated in variable becuase we will call it from start-job scope
function Wait_For_Jobs ([string]$jobsname){#Function will check every 45 seconds if all jobs are done. when done, break loop
    $completed = $false
        while (-not $completed) {
                $test = Get-Job -name "$jobsname*"| where-object {$_.state -match 'Running'}
                if ($test -eq $null){$completed = $true}
                start-sleep 45
                }
}
}

function Fire_UP ([int]$num_of_vm, [string]$prefix){#Deploy the VM's
    for ($i = 1; $i -le $num_of_vm; $i++){
      start-job -name "$JOBSNAME$i" -scriptblock{
            $VMName = "$using:prefix-$using:i"
            $vm=New-AzVm `
                -ResourceGroupName "HomeWork" `
                -Credential $using:cred `
                -Name "$VMName" `
                -Location "$using:LOCATION" `
                -VirtualNetworkName "$using:prefix-vnet" `
                -SubnetName "HomeWorkSubnet" `
                -SecurityGroupName "HomeWorkSecGroup" `
                -PublicIpAddressName "$VMName-pip" `
                -OpenPorts 3389 
              }
        start-sleep 3
        }
}

function Stop_VM_shutdown {#Stop VM machines with tag - shutdown
    $vms=get-azvm | Where-Object {$_.Tags['tag01'] -eq 'shutdown' } 
    if ($vms -eq $null){
        log "ALERT - No machines were found with tag01 = shutdown, Exiting..."
        exit
    }
    $str="Shutting Down all vm's with tag01 = shutdown: "
    $str+= $vms | select-object -expandproperty name
    log "$str"
    try {
        log "Success - Machines were shutdown"
        $vms | stop-azvm -Force
    }
        catch {
    log "FAIL - Could not shutdown machines"
    }
}


#Pre-Start

try {
    write-host "Please sign in your Azure Account"
    $AzAccount=Connect-AzAccount
    $uname = $AzAccount.Context.Account.Id
    log "SUCCESS - $uname Authenticated"
    }
    catch {
        write-host "Cannot Authenticate Azure Acount, Exiting..."
        Log "FAIL - Azure Authentication Failure, Script halt."
        exit
}

#Check if script was called with argument -shutdown
if ($args[0] -eq '-shutdown'){
    write-host "Shutting down VM's with tag01 = shutdown"
    Stop_VM_shutdown
    exit
}


#Script Start

#set azure Resource Group for work
try {
    write-host "Resource group for this script is : $ResourceGroup"
    New-AzResourceGroup -name $ResourceGroup -Location $LOCATION -force
    }
catch {
    write-host "Cannot create Resource group $ResourceGroup, Script will halt."
    Log "FAIL - cannot create Resource group"
    exit
}

#If log file doesnt exist - create it
if (-not (Test-path -Path $LOG_FILE -PathType Leaf)){Out-File -FilePath $LOG_FILE }

#Get VM Prefix and Number of VM's
[string]$VM_PREFIX = Read-Host "Hi There!, please enter desired prefix for vm's  "

$continue=$true#Will make sure we loop until we get correct input
while ($continue){
    try {
        [int]$VM_NUM = read-host "How many VM's would you like to deploy? (1 - $MAX_NUM_OF_VM)  "
        if ($VM_NUM -ge 1 -And $VM_NUM -le $MAX_NUM_OF_VM){$continue=$false}
            else {
            write-host "Plese enter number between 1 and $MAX_NUM_OF_VM"
            }
        }
        catch {
            Write-host "Bad input: Please enter number from 1 to $MAX_NUM_OF_VM"
            }
    }

Log "A Request has been issued for Creating $VM_NUM instances with prefix $VM_PREFIX" 

#Call the functions

Remove-Job -name "$JOBSNAME*"
#We're deploying the machines in parallel as requested,
#If even number of machines, half of them will get tagged - tag01 = shutdown
if (chk_if_num_is_even($VM_NUM)){
    Fire_UP $VM_NUM $VM_PREFIX
    start-sleep 3
    start-job -name "Boss" -InitializationScript $Scope_Wait_for_Jobs -scriptblock {
        Wait_For_Jobs "$using:JOBSNAME*"
        wait-job -name Boss
        $tag = @{'tag01' = 'shutdown'}
        $vms=get-azvm -ResourceGroup "$using:ResourceGroup"
        $num = $vms.count / 2
        #The log is to divide even number by 2 (example 6 / 2 = 3 and run a loop for machines 0 - 2)
        for ($i = 0; $i -lt $num; $i++ ){Update-AzTag -Tag $tag -ResourceId $vms[$i].Id -Operation Merge -Verbose}
    }
} 
else {
    Fire_UP $VM_NUM $VM_PREFIX
    start-sleep 3
    start-job -name "Boss" -InitializationScript $Scope_Wait_for_Jobs -scriptblock {
        Wait_For_Jobs "$using:JOBSNAME*"
        wait-job -name Boss
        $vms=get-azvm -ResourceGroup "$using:ResourceGroup"
        foreach ($vm in $vms){
            $name=$vm.name
            Add-AzVMDataDisk -VM $vm -Name "$name-Extra-Disk" -Caching 'ReadOnly' -DiskSizeInGB $using:DiskSize -Lun 0 -CreateOption Empty
            Update-AzVM -ResourceGroupName $using:ResourceGroup -vm $vm
       }
    }
}

#We test to see if desired number of vms equals deployed number of vms
if (Verify_Deploy $VM_NUM $ResourceGroup) {
    log "SUCCESS - All VM's were deployed!"
    }
    else {
        log "FAIL - Could not deploy all VM's"
    }