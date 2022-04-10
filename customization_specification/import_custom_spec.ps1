<#

.SYNOPSIS
import_custom_spec.ps1
Script imports a vCenter customization specification.

Author:
Torsten Sasse
Version 1.0

.DESCRIPTION
A vCenter customization specification is imported from xml file.
Checks if xml file exists.
Checks if custom spec already exists in vCenter.

Installed PowerCli module is required.

.INPUTS
Following inputs are requested during runtime:

vCenter FQDN
vCenter Credentials
customization specification (xml file)

.NOTES
THIS CODE AND ANY ASSOCIATED INFORMATION ARE PROVIDED “AS IS” WITHOUT
WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT
LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS
FOR A PARTICULAR PURPOSE. THE ENTIRE RISK OF USE, INABILITY TO USE, OR
RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.

#>

## vCenter FQDN input
$server = Read-Host `n"vCenter FQDN?"

## connect to vCenter
Try{
    Connect-VIserver -server $server -ErrorAction Stop | Out-Null
    }
    Catch{
        Write-Host "could not connect to $server " -ForegroundColor Red
        Write-Host "Check the FQDN and/or credentials for $server and start again " -ForegroundColor yellow
        exit
}

## filename input & check if exists
$fileName = Read-Host -Prompt `n"Which custom spec should be imported <specName>.xml (must be located in users home -Downloads- folder)"
if (-not(test-path -Path ~/Downloads/$fileName)) {
    Write-Host -ForegroundColor Red "file does not exist - for security reasons script stops here"
    Disconnect-VIserver -server $server -Confirm:$false
    Write-Host -ForegroundColor Green `n"Disconnected succesfully from " $server
    exit
}

## prepare for import using CustomizationSpecManager methods
$view = Get-View CustomizationSpecManager
$specXML = Get-Content ~/Downloads/$fileName
$spec = $view.XmlToCustomizationSpecItem($specXML)

## check if custom spec exists and decide to proceed / exit
if ($view.DoesCustomizationSpecExist($spec.Info.Name)) {
    Write-Host -ForegroundColor Red `n"This custom spec already exists - overwrite and proceed?"
    $answer = Read-Host `n"Yes (proceed) or No (exit)"

    while("yes","no" -notcontains $answer)
    {
        $answer = Read-Host "Yes or No"
    }
    if ($answer -eq "no") 
    {Write-Host -ForegroundColor Red `n"exit! nothing was imported! - please check existing custom specs in vCenter"
        Disconnect-VIserver -server $server -Confirm:$false
        Write-Host -ForegroundColor Green `n"Disconnected succesfully from " $server
     exit
    } 
}
    
## delete existing custom spec
if ($view.DoesCustomizationSpecExist($spec.Info.Name)) {$view.DeleteCustomizationSpec($spec.Info.Name)}

## import custom spec
$view.CreateCustomizationSpec($spec)

write-host -ForegroundColor Green `n"vCenter custom spec ***" $spec.Info.Name "*** was successfully imported to " $server

## disconnect & exit
Disconnect-VIServer -Server $server -Confirm:$false
Write-Host -ForegroundColor Green `n"Disconnected succesfully from " $server
