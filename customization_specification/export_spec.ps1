<#
.SYNOPSIS
export_custom_spec.ps1
Script exports a vCenter customization specification.

Author:
Torsten Sasse
Version 1.0

.DESCRIPTION
A vCenter customization specification is exported as xml to download folder of users home.
A list of all available customization specifications is provided.
This script works for Linux, Windows and MacOS.

Installed PowerCli module is required.

.INPUTS
Following inputs are requested during runtime:

vCenter FQDN
vCenter Credentials
customization specification name

.NOTES
THIS CODE AND ANY ASSOCIATED INFORMATION ARE PROVIDED “AS IS” WITHOUT
WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT
LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS
FOR A PARTICULAR PURPOSE. THE ENTIRE RISK OF USE, INABILITY TO USE, OR
RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER.


#>




# Helper Lines:
# Connect-VIServer -Server vifvvc010.str.if.de -User administrator@vsphere.local -Password 'vSphere$mgmt$2019'
# Get-View CustomizationSpecManager | Get-Member

$server=Read-Host `n"vCenter FQDN?"

Connect-VIServer -Server $server

$view=Get-View CustomizationSpecManager

Write-Host -ForegroundColor DarkYellow `n"Following specs are available for export"
""
$view.info.name

$name=Read-Host -Prompt `n"which spec should be exported?"

$spec=$view.GetCustomizationSpec($name)
$xml=$view.CustomizationSpecItemToXml($spec)
$xml | Out-File ~/Downloads/$name.xml

Write-Host -ForegroundColor Green `n"done!"
Write-Host `n"Find file here: ~/Downloads/$name.xml"

Disconnect-VIServer -Server $server -Confirm:$false