#################################################################
#                                                               #
# This script creates a local emergency user "localadm" on      #
# each host in a given cluster.                                 #
# Create local host account, role, and map account              #
#                                                               #
# Author: Torsten Sasse - InterFace AG                          #
# Contact: torsten.sasse@interface-ag.de                        #
#                                                               #
# Version 01.12.2017                                            #
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

#function: test password complexity

Function Test-PasswordForESXi {
    Param (
             [Parameter(Mandatory=$true)][string]$Password
          )
If ($Password.Length -lt 8) {
    return $false
}
If (
                 ($Password -cmatch "[A-Z\p{Lu}\s]") `
            -and ($Password -cmatch "[a-z\p{Ll}\s]") `
            -and ($Password -match "[\d]") `
            -and ($Password -match "[^\w]")  
        ) { 
            return $true
        }
     else {
            return $false

}
}



#connect to vCenter and ask for cluster name

Write-Host "In which vCenter are local emergency accounts needed?" -ForegroundColor Green
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
Write-Host "local account '$LocalAccount' will be created on these hosts" -ForegroundColor Cyan
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

#ask for new local host account initial password and check for typos and complexity

do {
Write-Host "provide a initial password for the new local host account. " -ForegroundColor Green
Write-Host "ESXi enforces password requirements for access from the Direct Console User Interface, the ESXi Shell, SSH, or the VMware Host Client.
By default, you have to include a mix of characters from four character classes: lowercase letters, uppercase letters, numbers, and special characters such as underscore or dash when you create a password.
By default, password length is more than 7 and less than 40." -ForegroundColor DarkYellow

$pwd1 = Read-Host "Password" -AsSecureString
$pwd2 = Read-Host "Re-enter Password" -AsSecureString
$pwd1_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwd1))
$pwd2_text = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwd2))
$result = Test-PasswordForESXi $pwd1_text
}
while (($pwd1_text -ne $pwd2_text) -or ($result -eq $false))
Write-Host "Passwords matched" -ForegroundColor Yellow


#connect to each host in cluster. Create local host account, role, and map account to role at host root level

foreach ($esxi in $hostlist) {
    Try{
        Connect-VIServer -Server $esxi -Credential $Hcred -ErrorAction Stop | Out-Null
        Write-Host ""
        Write-Host "connect to host $esxi; create account & role and set permissions" -ForegroundColor Yellow
        Write-Host ""
    }
    Catch{
        Write-Host "credentials not valid on $esxi" -ForegroundColor Red
        Write-Host "Check the credentials for $esxi and try again " -ForegroundColor yellow
        Disconnect-VIserver -server $vCenter -Verbose -Force -Confirm:$false
        exit
    }
    $priv = Get-VIPrivilege -ID VirtualMachine.Interact.PowerOn,VirtualMachine.Interact.PowerOff,VirtualMachine.Interact.ConsoleInteract -Server $esxi
    $ent = Get-Folder -Server $esxi -Type Datacenter
    Try{
        New-VMHostAccount -Id $LocalAccount -Description $AccountDiscr -Password $pwd1_text -Server $esxi -ErrorAction Stop | Out-Null
    }
    Catch{
        Write-Host "$LocalAccount already exists on $esxi" -ForegroundColor Red
        Write-Host "Check the permissions on hosts in cluster $cluster and try again " -ForegroundColor yellow
        Disconnect-VIserver -server $vCenter -Verbose -Force -Confirm:$false
        exit
    }
    New-VIRole -Name $RoleName -Server $esxi -Privilege $priv | Out-Null
    New-VIPermission -Entity $ent -Principal $LocalAccount -Role $RoleName -Server $esxi | Out-Null
    Disconnect-VIServer -Server $esxi -Verbose -Force -Confirm:$false  | Out-Null
    
}

#disconnect from vCenter
Write-Host ""
Write-Host ""
Write-Host "Accounts & roles are created. Permissions granted!" -ForegroundColor green
Write-Host ""
Write-Host ""
Disconnect-VIserver -server $vCenter -Verbose -Force -Confirm:$false
