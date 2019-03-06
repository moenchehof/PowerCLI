#################################################################
#                                                               #
# This script removes the local emergency user on each host in  #
# a given cluster; removes the "EmergencyAccess" role and       #
# permissions mapped to this user                               #
#                                                               #
# Author: Torsten Sasse - InterFace AG                          #
# Contact: torsten.sasse@interface-ag.de                        #
#                                                               #
# Version 4                                                     #
#                                                               #
#################################################################


Set-PowerCLIConfiguration -DefaultVIServerMode multiple -Confirm:$false
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$False
Set-PowerCLIConfiguration -ProxyPolicy NoProxy -Confirm:$False
Write-Host ""
Write-Host ""

# Check whether PowerShell runs in an elevated session

$WindowsIdentity = [system.security.principal.windowsidentity]::GetCurrent()
$Principal = New-Object System.Security.Principal.WindowsPrincipal($WindowsIdentity)
$AdminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator

if ($Principal.IsInRole($AdminRole))
    {
    Write-Host -ForegroundColor Green "Elevated PowerShell session detected. Continuing."
    Write-Host ""
    Write-Host ""
    }
else
    {
    Write-Host -ForegroundColor Red "This application/script must be run in an elevated PowerShell window. Please launch an elevated session and try again."
Break
}


#connect to vCenter and ask for cluster name

Write-Host "In which vCenter are local emergency accounts need to be removed?" -ForegroundColor Green
$vCenter = Read-Host "enter vCenter FQDN ..."
$Vcred = Get-Credential -Message "provide credentials for $vCenter"
Write-Host "logging into $vCenter"

Try{
    Connect-VIserver -server $vCenter -Credential $Vcred -ErrorAction Stop | Out-Null
    }
    Catch{
        Write-Host "could not connect to $vCenter " -ForegroundColor Red
        Write-Host "Check the credentials for $vCenter and start again " -ForegroundColor yellow
        exit
}

Write-Host "Please provide a cluster name in $vCenter" -foregroundcolor "Green"
$cluster = Read-Host "ClusterName "

#define account and role name

$RoleName = "EmergencyAccess"
$LocalAccount = "localadm"
$AccountDiscr = "local emergency user"

#list hosts within given cluster

Write-Host ""
Write-Host ""
Write-Host "found following hosts in cluster" $cluster

$hostlist =Get-Cluster $cluster | Get-VMhost | Select-Object -ExpandProperty Name 
$hostlist

#check hostnames before proceeding

Write-Host ""
Write-Host "local account '$LocalAccount', role '$RoleName' and permissions will be removed on these hosts" -ForegroundColor Cyan
$answer = Read-Host "Yes (proceed) or No (exit)"

while("yes","no" -notcontains $answer)
{
	$answer = Read-Host "Yes or No"
}
if ($answer -eq "no") 
{Disconnect-VIserver -server $vCenter -Verbose -Force -Confirm:$false
 exit
}

#ask for host root credentials

$Hcred = Get-Credential -Message "provide host root credentials for hosts in cluster $cluster"
Write-Host ""
Write-Host ""


#connect to each host in cluster. Delete local host account and role, remove permission at host root level

foreach ($esxi in $hostlist) {
   
        Connect-VIServer -Server $esxi -Credential $Hcred | Out-Null
        Write-Host ""
        Write-Host "connect to host $esxi; delete account & role and remove permissions" -ForegroundColor Yellow
        Write-Host ""
    
    
        $permission = Get-VIPermission -Principal $LocalAccount -Server $esxi
        Remove-VIPermission -Permission $permission -Verbose
        $Haccount = Get-VMHostAccount -User -Id $LocalAccount -Server $esxi
        Remove-VMHostAccount -HostAccount $Haccount -Server $esxi -Verbose
        Remove-VIRole -Role $RoleName -Server $esxi -Verbose
         
        Disconnect-VIServer -Server $esxi -Verbose -Force -Confirm:$false  
}

#disconnect from vCenter
Write-Host ""
Write-Host ""
Write-Host "Accounts & roles are deleted. Permissions are removed!" -ForegroundColor green
Write-Host ""
Write-Host ""
Disconnect-VIserver -server $vCenter -Verbose -Force -Confirm:$false
