###########################################################################################################################
# Cisco UCS Automated Configuration and Provisioning Script Version 1 by Chris Nickl, @ck_nic, chris.nickl@wwt.com        #
###########################################################################################################################

######################################################################################################################################
# Setup Prerequisit Requirements - VERY IMPORTATNT TO READ THIS LIST FOR PROPER SCRIPT OPERATION                                     #
#   - Microsoft PowerShell 2 is required. PowerShell 2 is part of Windows 7/2008 R2			   			    						 #
#   - Cisco UCS PowerTool version 0.98 for UCSM - http://developer.cisco.com/web/unifiedcomputing/pshell-download                    #
#   - The default local admin user and password						                                           					     #
#   - A UCS cluser that the initail IPs and cluster config have been completed from the console   			          			     #
#   - For 6248 Fabric Interconnects use the Unified Port Wizard to set the FC ports on both Fabrics                                  # 
#   - Update the firmware to at least version 2.02q                                                                                  # 
#   - Ensure the Variables Excel Sheet is fully filled out                                                                           # 
#   - For the LAN/SAN Port-Channels in the below script set the correct port and slot IDs                                            #
#   - After the script completes login to UCSM and verify config                                                                     #
#   - Enable the LAN/SAN port-channels and verify they come up on both sides                                                         #
######################################################################################################################################

###############################################################################################################################
# This Script was built by taking a "Best-of-Breed" approach from many scripts i've found.  I want to thank the following ;   #
# Jeremy Waldrop, Matt Oswalt, Chris Carter and a host of others for creating the inital scripts i've merged here             #
#                                                                                                                             #
#  Current Version 0.2 7/30/13  #
#                               #
#  Change Log:                  #
###############################################################################################################################

###########################
# Sets up basic functions #
###########################
 
param([parameter(mandatory=$true)][validateNotNullOrEmpty()]$excelFile, [switch]$toConsole)

function Remove-File
{
	param($fileName)
	if (Test-Path($fileName)) { del $fileName }
} ##### End of function Remove-File

##### set up script logging
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
$thisPath = Split-Path (Resolve-Path $MyInvocation.MyCommand.Path)
Set-Location $thisPath
$scriptLog = "UCS_Build_Script_Log.txt"
$scriptLogFullPath = Join-Path $thisPath $scriptLog
Start-Transcript $scriptLogFullPath -Append
Write-Host "Starting script logging."

##### make sure the CiscoUcsPS module is loaded
if (!(Get-Module -Name CiscoUcsPs))
{
	Write-Host "Import module CiscoUcsPs"
	try {Import-Module CiscoUcsPs }
	catch
	{
		Write-Host "..Importing module CiscoUcsPs failed. Quit the script."
		exit(1)
	}
}


######################################
# Do the import from the Excel Sheet #
######################################

##### make sure the Excel file exists
if (!(Test-Path $excelFile))
{ Write-Host "The Excel file, $excelFile, does not exist. Quit the script."; exit(2) }

Write-Host "Read the excel file..."
$fullPathName = Join-Path $thisPath $excelFile
try { $excel = New-Object -ComObject Excel.Application}
catch {
	Write-Host "..Failed to access to Excel application. Quit the script."
	exit(2)
}
$excel.Visible = $false
try { $wb = $excel.Workbooks.Open($fullPathName) }
catch {
	Write-Host "..Failed to open the Excel file, $fullPathName. Quit the script."
	$excel.Quit()
	Remove-ComObject
	exit(3)
}


### First go to Customer sheet
$cust_sheet_name = "Customer Filled Out"
Write-Host "Open worksheet $cust_sheet_name..."
try { $ws1 = $wb.Worksheets.Item($cust_sheet_name) }
catch {
	Write-Host "..Cannot open worksheet $cust_sheet_name. Quit the script."
	$wb.Close()
	$excel.Quit()
	Remove-ComObject
	exit(4)
}
$ws1.Activate()

Write-Host "Read values from worksheet $cust_sheet_name..."
[string]$ucsm_mgmt_address = $ws1.Cells.Item(3, 2).Value2; if (!$ucsm_mgmt_address) { "..UCSM IP is missing!! Exiting!! "; exit }; $ucsm_mgmt_address = $ucsm_mgmt_address.Trim()
[string]$mgmt_ip_pool_start = $ws1.Cells.Item(4, 2).Value2; if (!$mgmt_ip_pool_start) { "..KVM Mgmt IP From is missing!!! Exiting!!"; exit }; $mgmt_ip_pool_start = $mgmt_ip_pool_start.Trim()
[string]$mgmt_ip_pool_end = $ws1.Cells.Item(5, 2).Value2; if (!$mgmt_ip_pool_end) { "..KVM Mgmt IP To is missing!!! Exiting!!"; exit }; $mgmt_ip_pool_end = $mgmt_ip_pool_end.Trim()
[string]$mgmt_ip_pool_mask= $ws1.Cells.Item(6, 2).Value2; if (!$mgmt_ip_pool_mask) { "..KVM Mgmt IP Subnet Mask is missing!!! Exiting!!"; exit }; $mgmt_ip_pool_mask = $mgmt_ip_pool_mask.Trim()
[string]$mgmt_ip_pool_gw = $ws1.Cells.Item(7, 2).Value2; if (!$mgmt_ip_pool_gw) { "..KVM Mgmt IP Default Gateway is missing!!! Exiting!!"; exit }; $mgmt_ip_pool_gw = $mgmt_ip_pool_gw.Trim()
[string]$ucsm_username = $ws1.Cells.Item(8, 2).Value2; if (!$ucsm_username) { "..UCSM Username is missing!! Exiting!!"; exit }; $ucsm_username = $ucsm_username.Trim()
[string]$ucsm_password = $ws1.Cells.Item(9, 2).Value2; if (!$ucsm_password) { "..UCSM Password is missing!! Exiting!!"; exit }; $ucsm_password = $ucsm_password.Trim()
[string]$site_id = $ws1.Cells.Item(10, 2).Value2; if (!$site_id) { "..Site ID is missing!!! Exiting!!"; exit }; $site_id = $site_id.Trim()
[string]$site_descr = $ws1.Cells.Item(11, 2).Value2; if (!$site_descr) { $site_descr = "Site Missing" } 
[string]$pod_id = $ws1.Cells.Item(12, 2).Value2; if (!$pod_id) { "..POD ID is missing!!! Exiting!!"; exit }; $pod_id = $pod_id.Trim()
[string]$pod_descr = $ws1.Cells.Item(13, 2).Value2; if (!$pod_descr) { $pod_descr = "Pod Description is Missing" }
[string]$organization = $ws1.Cells.Item(14, 2).Value2; if (!$organization) { "...Organization is missing!! Exiting!!"; exit }; $Organization = $Organization.Trim()
[string]$ntp_1 = $ws1.Cells.Item(15, 2).Value2; if (!$ntp_1) { "..NTP Server #1 is Missing" }; $ntp_1 = $ntp_1.Trim()
[string]$ntp_2 = $ws1.Cells.Item(16, 2).Value2; if (!$ntp_2) { "..NTP Server #2 is Missing" }; $ntp_2 = $ntp_2.Trim()
[string]$dns_1 = $ws1.Cells.Item(17, 2).Value2; if (!$dns_1) { "..DNS Server #1 is Missing" }; $dns_1 = $dns_1.Trim()
[string]$dns_2 = $ws1.Cells.Item(18, 2).Value2; if (!$dns_2) { "..DNS Server #2 is Missing" }; $dns_2 = $dns_2.Trim()
[string]$time_zone = $ws1.Cells.Item(19, 2).Value2; if (!$time_zone) { "..Timezone is missing" }; $time_zone = $time_zone.Trim()
[string]$vsan_a_name = $ws1.Cells.Item(20, 2).Value2; if (!$vsan_a_name) { "..VSAN A Name is Missing!! Exiting!!"; exit }; $vsan_a_name = $vsan_a_name.Trim()
[string]$vsan_a_id = $ws1.Cells.Item(21, 2).Value2; if (!$vsan_a_id) { ".. VSAN A ID is Missing!! Exiting!!"; exit }; $vsan_a_id = $vsan_a_id.Trim()
[string]$vsan_b_name = $ws1.Cells.Item(22, 2).Value2; if (!$vsan_b_name) { "..VSAN B Name is Missing!! Exiting!!"; exit }; $vsan_b_name = $vsan_b_name.Trim()
[string]$vsan_b_id = $ws1.Cells.Item(23, 2).Value2; if (!$vsan_b_id) { "..VSAN B ID is Missing!! Exiting!!"; exit }; $vsan_b_id = $vsan_b_id.Trim()
[string]$fcoe_vlan_a = $ws1.Cells.Item(24, 2).Value2; if (!$fcoe_vlan_a) { "..FCoE VLAN A Missing!! Exiting!!"; exit }; $fcoe_vlan_a = $fcoe_vlan_a.Trim()
[string]$fcoe_vlan_b = $ws1.Cells.Item(25, 2).Value2; if (!$fcoe_vlan_b) { "..FCoE VLAN B is Missing!! Exiting!!"; exit }; $fcoe_vlan_b = $fcoe_vlan_b.Trim()
[string]$uuid_name = $ws1.Cells.Item(27, 2).Value2; if (!$uuid_name) { "..UUID Pool Name is Missing!! Exiting!!"; exit }; $uuid_name = $uuid_name.Trim()
[string]$mac_pool_esx_mgmt_id = $ws1.Cells.Item(29, 2).Value2; if (!$mac_pool_esx_mgmt_id) { "..MAC Pool ESX Mgmt ID is Missing!! Exiting!!"; exit }; $mac_pool_esx_mgmt_id = $mac_pool_esx_mgmt_id.Trim()
[string]$mac_pool_esx_mgmt_name = $ws1.Cells.Item(28, 2).Value2; if (!$mac_pool_esx_mgmt_name) { "..MAC Pool ESX Mgmt Name is Missing!! Exiting!!"; exit }; $mac_pool_esx_mgmt_name = $mac_pool_esx_mgmt_name.Trim()
[string]$mac_pool_esa_vmdata_id = $ws1.Cells.Item(31, 2).Value2; if (!$mac_pool_esa_vmdata_id) { "..MAC Pool ESA VMData ID is Missing!! Exiting!!"; exit }; $mac_pool_esa_vmdata_id = $mac_pool_esa_vmdata_id.Trim()
[string]$mac_pool_esa_vmdata_name = $ws1.Cells.Item(30, 2).Value2; if (!$mac_pool_esa_vmdata_name) { "..MAC Pool ESA Data Name is Missing!! Exiting!!"; exit }; $mac_pool_esa_vmdata_name = $mac_pool_esa_vmdata_name.Trim()
[string]$mac_pool_int_vmdata_id = $ws1.Cells.Item(33, 2).Value2; if (!$mac_pool_int_vmdata_id) { "..MAC Pool INT VMData ID is Missing!! Exiting!!"; exit }; $mac_pool_int_vmdata_id = $mac_pool_int_vmdata_id.Trim()
[string]$mac_pool_int_vmdata_name = $ws1.Cells.Item(32, 2).Value2; if (!$mac_pool_int_vmdata_name) { "..MAC Pool INT VMData Name is Missing!! Exiting!!"; exit }; $mac_pool_int_vmdata_name = $mac_pool_int_vmdata_name.Trim()
[string]$mac_pool_windows_id = $ws1.Cells.Item(35, 2).Value2; if (!$mac_pool_windows_id) { "..MAC Pool Windows ID is Missing!! Exiting!!"; exit }; $mac_pool_windows_id = $mac_pool_windows_id.Trim()
[string]$mac_pool_windows_name = $ws1.Cells.Item(34, 2).Value2; if (!$mac_pool_windows_name) { "..MAC Pool Windows Name is Missing!! Exiting!!"; exit }; $mac_pool_windows_name = $mac_pool_windows_name.Trim()
[string]$mac_pool_cseries_name = $ws1.Cells.Item(36, 2).Value2; if (!$mac_pool_cseries_name) { "..MAC Pool C-Series Name is Missing!! Exiting!!"; exit }; $mac_pool_cseries_name = $mac_pool_cseries_name.Trim()
[string]$mac_pool_cseries_id = $ws1.Cells.Item(37, 2).Value2; if (!$mac_pool_cseries_id) { "..MAC Pool C-Series ID is Missing!! Exiting!!"; exit }; $mac_pool_cseries_id = $mac_pool_cseries_id.Trim()

[string]$wwnn_pool_name = $ws1.Cells.Item(38, 2).Value2; if (!$wwnn_pool_name) { "..WWNN Pool Name is Missing!! Exiting!!"; exit }; $wwnn_pool_name = $wwnn_pool_name.Trim()
[string]$wwpn_pool_name = $ws1.Cells.Item(39, 2).Value2; if(!$wwpn_pool_name) { "..WWPN Pool Name is Missing!! Exiting!!"; exit }; $wwpn_pool_name = $wwpn_pool_name.Trim()

[string]$vnic_template_a_esxi_mgmt_name = $ws1.Cells.Item(41, 2).Value2; if(!$vnic_template_a_esxi_mgmt_name) { "..ESXi Mgmt vNIC Template A Name is Missing!! Exiting!!"; exit }; $vnic_template_a_esxi_mgmt_name = $vnic_template_a_esxi_mgmt_name.Trim()
[string]$vnic_template_a_esa_vmdata_name = $ws1.Cells.Item(42, 2).Value2; if(!$vnic_template_a_esa_vmdata_name) { " ..ESA VMData vNIC Template A Name is Missing!! Exiting!!"; exit }; $vnic_template_a_esa_vmdata_name = $vnic_template_a_esa_vmdata_name.Trim()
[string]$vnic_template_a_int_vmdata_name = $ws1.Cells.Item(43, 2).Value2; if(!$vnic_template_a_int_vmdata_name) { "..INT VMData vNIC Template A Name is Missing!! Exiting!!"; exit }; $vnic_template_a_int_vmdata_name = $vnic_template_a_int_vmdata_name.Trim()
[string]$vnic_template_a_windows_name = $ws1.Cells.Item(44, 2).Value2; if(!$vnic_template_a_windows_name) { "..Windows vNIC Template A Name is Missing!! Exiting!!"; exit }; $vnic_template_a_windows_name = $vnic_template_a_windows_name.Trim()
[string]$vnic_template_a_cseries_name = $ws1.Cells.Item(45, 2).Value2; if(!$vnic_template_a_cseries_name) { "..C-Series vNIC Template A Name is Missing!! Exiting!!"; exit }; $vnic_template_a_cseries_name = $vnic_template_a_cseries_name.Trim()

[string]$vnic_template_b_esxi_mgmt_name = $ws1.Cells.Item(46, 2).Value2; if(!$vnic_template_b_esxi_mgmt_name) { "..ESXi Mgmt vNIC Template B Name is Missing!! Exiting!!"; exit }; $vnic_template_b_esxi_mgmt_name = $vnic_template_b_esxi_mgmt_name.Trim()
[string]$vnic_template_b_esa_vmdata_name = $ws1.Cells.Item(47, 2).Value2; if(!$vnic_template_b_esa_vmdata_name) { " ..ESA VMData vNIC Template B Name is Missing!! Exiting!!"; exit }; $vnic_template_b_esa_vmdata_name = $vnic_template_b_esa_vmdata_name.Trim()
[string]$vnic_template_b_int_vmdata_name = $ws1.Cells.Item(48, 2).Value2; if(!$vnic_template_b_int_vmdata_name) { "..INT VMData vNIC Template B Name is Missing!! Exiting!!"; exit }; $vnic_template_b_int_vmdata_name = $vnic_template_b_int_vmdata_name.Trim()
[string]$vnic_template_b_windows_name = $ws1.Cells.Item(49, 2).Value2; if(!$vnic_template_b_windows_name) { "..Windows Template B Name is Missing!! Exiting!!"; exit }; $vnic_template_b_windows_name = $vnic_template_b_windows_name.Trim()
[string]$vnic_template_b_cseries_name = $ws1.Cells.Item(50, 2).Value2; if(!$vnic_template_b_cseries_name) { "..Windows Template B Name is Missing!! Exiting!!"; exit }; $vnic_template_b_cseries_name = $vnic_template_b_cseries_name.Trim()

[string]$vhba_template_a_name = $ws1.Cells.Item(51, 2).Value2; if(!$vhba_template_a_name) { "..vHBA Template A Name is Missing!! Exiting!!"; exit }; $vhba_template_a_name = $vhba_template_a_name.Trim()
[string]$vhba_template_b_name = $ws1.Cells.Item(52, 2).Value2; if(!$vhba_template_b_name) { "..vHBA Template B Name is Missing!! Exiting!!"; exit }; $vhba_template_b_name = $vhba_template_b_name.Trim()

#[string]$profile_template_esx_name = $ws1.Cells.Item(53, 2).Value2; if(!$profile_template_esx_name) { "..Service Profile Template for ESX Name is Missing!! Exiting!!"; exit }; $profile_template_esx_name = $profile_template_esx_name.Trim()
#[string]$profile_esxi_prefix = $ws1.Cells.Item(54, 2).Value2; if(!$profile_esxi_prefix) { "..ESXi Service Profile Prefix is Missing!! Exiting!!"; exit }; $profile_esxi_prefix = $profile_esxi_prefix.Trim()
#[string]$profile_template_2k3_name = $ws1.Cells.Item(55, 2).Value2; if(!$profile_template_2k3_name) { "..Service Profile Template for 2k3 Name is Missing!! Exiting!!"; exit }; $profile_template_2k3_name = $profile_template_2k3_name.Trim()
#[string]$profile_2k3_prefix = $ws1.Cells.Item(56, 2).Value2; if(!$profile_2k3_prefix) { "..2k3 Service Profile Prefix is Missing!! Exiting!!"; exit }; $profile_2k3_prefix = $profile_2k3_prefix.Trim()
#[string]$profile_template_2k8_name = $ws1.Cells.Item(57, 2).Value2; if(!$profile_template_2k8_name) { "..Service Profile Template for 2k8 Name is Missing!! Exiting!!"; exit }; $profile_template_2k8_name = $profile_template_2k8_name.Trim()
#[string]$profile_2k8_prefix = $ws1.Cells.Item(58, 2).Value2; if(!$profile_2k8_prefix) { "..2k8 Service Profile Prefix is Missing!! Exiting!!"; exit }; $profile_2k8_prefix = $profile_2k8_prefix.Trim()
#[string]$profile_template_cseries_name = $ws1.Cells.Item(59, 2).Value2; if(!$profile_template_cseries_name) { "..Service Profile Template for C-Series Name is Missing!! Exiting!!"; exit }; $profile_template_cseries_name = $profile_template_cseries_name.Trim()
#[string]$profile_cseries_prefix = $ws1.Cells.Item(60, 2).Value2; if(!$profile_cseries_prefix) { "..2k8 Service Profile Prefix is Missing!! Exiting!!"; exit }; $profile_cseries_prefix = $profile_cseries_prefix.Trim()



### Now go to WWT sheet
#$wwt_sheet_name = "WWT Filled Out"
#Write-Host "Open worksheet $wwt_sheet_name..."
#try { $ws2 = $wb.Worksheets.Item($wwt_sheet_name) }
#catch {
#	Write-Host "..Cannot open worksheet $wwt_sheet_name. Quit the script."
#	$wb.Close()
#	$excel.Quit()
#	Remove-ComObject
#	exit(4)
#}
#$ws2.Activate()
#
#Write-Host "Read values from worksheet $wwt_sheet_name..."
#[string]$server_port_1 = $ws2.Cells.Item(3, 2).Value2; if(!$server_port_1) { "..Server Port #1 is Missing!! Exiting!!"; exit }; $server_port_1 = $server_port_1.Trim()
#[string]$server_port_2 = $ws2.Cells.Item(4, 2).Value2; if(!$server_port_2) { "..Server Port #2 is Missing!! Exiting!!"; exit }; $server_port_2 = $server_port_2.Trim()
#[string]$eth_uplink_port_1 = $ws2.Cells.Item(5, 2).Value2; if(!$eth_uplink_port_1) { "..Ethernet Uplink Port #1 is Missing!! Exiting!!"; exit }; $eth_uplink_port_1 = $eth_uplink_port_1.Trim()
#[string]$eth_uplink_port_2 = $ws2.Cells.Item(6, 2).Value2; if(!$eth_uplink_port_2) { "..Ethernet Uplink Port #2 is Missing!! Exiting!!"; exit }; $eth_uplink_port_2 = $eth_uplink_port_2.Trim()
#[string]$fc_uplink_port_1 = $ws2.Cells.Item(7, 2).Value2; if(!$fc_uplink_port_1) { "..FC Uplink Port #1 is Missing!! Exiting!!"; exit }; $fc_uplink_port_1 = $fc_uplink_port_1.Trim()
#[string]$fc_uplink_port_2 = $ws2.Cells.Item(8, 2).Value2; if(!$fc_uplink_port_2) { "..FC Uplink Port #2 is Missing!! Exiting!!"; exit }; $fc_uplink_port_2 = $fc_uplink_port_2.Trim()
#[string]$eth_pc_name_a = $ws2.Cells.Item(9, 2).Value2; if(!$eth_pc_name_a) { "..Ethernet Port-Channel A Name is Missing!! Exiting!!"; exit }; $eth_pc_name_a = $eth_pc_name_a.Trim()
#[string]$eth_pc_a_id = $ws2.Cells.Item(10, 2).Value2; if(!$eth_pc_a_id) { "..Ethernet Port-Channel A ID is Missing!! Exiting!!"; exit }; $eth_pc_a_id = $eth_pc_a_id.Trim()
#[string]$eth_pc_name_b = $ws2.Cells.Item(11, 2).Value2; if(!$eth_pc_name_b) { "..Ethernet Port-Channel B Name is Missing!! Exiting!!"; exit }; $eth_pc_name_b = $eth_pc_name_b.Trim()
#[string]$eth_pc_b_id = $ws2.Cells.Item(12, 2).Value2; if(!$eth_pc_b_id) { "..Ethernet Port-Channel B ID is Missing!! Exiting!!"; exit }; $eth_pc_b_id = $eth_pc_b_id.Trim()
#

##### close Excel and cleanup
Write-Host "Close Excel file..."
$wb.Close()
$excel.Quit()
Remove-Variable wb, excel
Start-Sleep -Seconds 2

###############################################
# Setup Static & Derived Variables for Script #
###############################################
Write-Host "Create Static & Derived Variables"
$eth_uplink_slot = "1"
#### uuid pool
$uuid_descr = "UUID Pool for Site ID" + $site_id + "Pod ID" + $pod_id
$uuid_from = "0000-" + $site_id + $pod_id + "0000000001"
$uuid_to = "0000-" + $site_id + $pod_id + "0000000256"

##### mac pools
##### mac pool ESXi_Mgmt
$mac_pool_esx_mgmt_a_name = $mac_pool_esx_mgmt_name + "_A"
$mac_pool_esx_mgmt_a_from = "00:25:B5:" + $site_id + $pod_id + ":$mac_pool_esx_mgmt_id" + "A:01"
$mac_pool_esx_mgmt_a_to = "00:25:B5:" + $site_id + $pod_id + ":$mac_pool_esx_mgmt_id" + "A:FF" #### 256 mac addresses
$mac_pool_esx_mgmt_b_name = $mac_pool_esx_mgmt_name + "_B"
$mac_pool_esx_mgmt_b_from = "00:25:B5:" + $site_id + $pod_id + ":$mac_pool_esx_mgmt_id" + "B:01"
$mac_pool_esx_mgmt_b_to = "00:25:B5:" + $site_id + $pod_id + ":$mac_pool_esx_mgmt_id" + "B:FF" #### 256 mac addresses

##### mac pool ESA VMData
$mac_pool_esa_vmdata_a_name = $mac_pool_esa_vmdata_name + "_A"
$mac_pool_esa_vmdata_a_from = "00:25:B5:" + $site_id + $pod_id + ":$mac_pool_esa_vmdata_id" + "A:01"
$mac_pool_esa_vmdata_a_to = "00:25:B5:" + $site_id + $pod_id + ":$mac_pool_esa_vmdata_id" + "A:FF" #### 256 mac addresses
$mac_pool_esa_vmdata_b_name = $mac_pool_esa_vmdata_name + "_B"
$mac_pool_esa_vmdata_b_from = "00:25:B5:" + $site_id + $pod_id + ":$mac_pool_esa_vmdata_id" + "B:01"
$mac_pool_esa_vmdata_b_to = "00:25:B5:" + $site_id + $pod_id + ":$mac_pool_esa_vmdata_id" + "B:FF" #### 256 mac addresses

##### mac pool INT VMData
$mac_pool_int_vmdata_a_name = $mac_pool_int_vmdata_name + "_A"
$mac_pool_int_vmdata_a_from = "00:25:B5:" + $site_id + $pod_id + ":$mac_pool_int_vmdata_id" + "A:01"
$mac_pool_int_vmdata_a_to = "00:25:B5:" + $site_id + $pod_id + ":$mac_pool_int_vmdata_id" + "A:FF" #### 256 mac addresses
$mac_pool_int_vmdata_b_name = $mac_pool_int_vmdata_name + "_B"
$mac_pool_int_vmdata_b_from = "00:25:B5:" + $site_id + $pod_id + ":$mac_pool_int_vmdata_id" + "B:01"
$mac_pool_int_vmdata_b_to = "00:25:B5:" + $site_id + $pod_id + ":$mac_pool_int_vmdata_id" + "B:FF" #### 256 mac addresses

##### mac pool Windows
$mac_pool_windows_a_name = $mac_pool_windows_name + "_A"
$mac_pool_windows_a_from = "00:25:B5:" + $site_id + $pod_id + ":$mac_pool_windows_id" + "A:01"
$mac_pool_windows_a_to = "00:25:B5:" + $site_id + $pod_id + ":$mac_pool_windows_id" + "A:FF" #### 256 mac addresses
$mac_pool_windows_b_name = $mac_pool_windows_name + "_B"
$mac_pool_windows_b_from = "00:25:B5:" + $site_id + $pod_id + ":$mac_pool_windows_id" + "B:01"
$mac_pool_windows_b_to = "00:25:B5:" + $site_id + $pod_id + ":$mac_pool_windows_id" + "B:FF" #### 256 mac addresses

##### mac pool C-Series
$mac_pool_cseries_a_name = $mac_pool_cseries_name + "_A"
$mac_pool_cseries_a_from = "00:25:B5:" + $site_id + $pod_id + ":$mac_pool_cseries_id" + "A:01"
$mac_pool_cseries_a_to = "00:25:B5:" + $site_id + $pod_id + ":$mac_pool_cseries_id" + "A:FF" #### 256 mac addresses
$mac_pool_cseries_b_name = $mac_pool_cseries_name + "_B"
$mac_pool_cseries_b_from = "00:25:B5:" + $site_id + $pod_id + ":$mac_pool_cseries_id" + "B:01"
$mac_pool_cseries_b_to = "00:25:B5:" + $site_id + $pod_id + ":$mac_pool_cseries_id" + "B:FF" #### 256 mac addresses


#### wwnn pool
$wwnn_pool_from = "20:00:00:25:B5:" + $site_id + $pod_id + ":00:01"
$wwnn_pool_to = "20:00:00:25:B5:" + $site_id + $pod_id + ":00:FF" #### 256 wwnn addresses

#### wwpn pools
$wwpn_pool_a_name = $wwpn_pool_name + "_A"
$wwpn_pool_b_name = $wwpn_pool_name + "_B"
$wwpn_a_from = "20:00:00:25:B5:" + $site_id + $pod_id + ":1A:01"
$wwpn_a_to = "20:00:00:25:B5:" + $site_id + $pod_id + ":1A:FF" #### 256 wwpn addresses on fab_a
$wwpn_b_from = "20:00:00:25:B5:" + $site_id + $pod_id + ":1B:01"
$wwpn_b_to = "20:00:00:25:B5:" + $site_id + $pod_id + ":1B:FF" #### 256 wwpn addresses on fab_b

##### polices
#### bios policy
$bios_policy_name = "BIOS_Policy"

#### server pool
$server_pool_b200m3_name = "B200_M3_Pool"
$server_pool_policy_b200m3_name = "B200_M3_Pool"
$server_pool_b200m2_name = "B200_M2_Pool"
$server_pool_policy_b200m2_name = "B200_M2_Pool"
$server_pool_b230m2_name = "B230_M2_Pool"
$server_pool_policy_b230m2_name = "B230_M2_Pool"


#### boot policy
$boot_policy_fab_a_name = "SAN_Boot_Fab_A"
$boot_policy_fab_b_name = "SAN_Boot_Fab_B"

###################
# Connect to UCSM #
###################
Write-Host "Connecting to UCSM"
$ucsm_sec_password = ConvertTo-SecureString $ucsm_password -AsPlainText -Force
$ucsm_creds = New-Object System.Management.Automation.PSCredential($ucsm_username, $ucsm_sec_password)

## Make sure no other connection is active
Disconnect-Ucs

## Connect
Connect-Ucs $ucsm_mgmt_address -Credential $ucsm_creds
#Connect-Ucs $ucsm_mgmt_address

##############################################################
# Set Global System Policies for chassis discovery and power #
##############################################################
Write-Host "Creating Global System Policies"
Get-UcsChassisDiscoveryPolicy | Set-UcsChassisDiscoveryPolicy -Action 1-link -LinkAggregationPref port-channel -Rebalance user-acknowledged -Force
Get-UcsPowerControlPolicy | Set-UcsPowerControlPolicy -Redundancy grid -Force

## CIMC Pool
Get-UcsIpPool -Name ext-mgmt -LimitScope | Add-UcsIpPoolBlock -DefGw $mgmt_ip_pool_gw -From $mgmt_ip_pool_start -To $mgmt_ip_pool_end -modifypresent:$true


##############################################
# Configure Fabric Interconnect Server Ports #
##############################################
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 1 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 2 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 3 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 4 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 5 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 6 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 7 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 8 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 9 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 10 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 11 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 12 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 13 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 1 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 2 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 3 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 4 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 5 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 6 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 7 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 8 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 9 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 10 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 11 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 12 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id A | Add-UcsServerPort -AdminState enabled -PortId 13 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 1 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 2 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 3 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 4 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 5 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 6 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 7 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 8 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 9 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 10 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 11 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 12 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 13 -SlotId 1 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 1 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 2 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 3 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 4 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 5 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 6 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 7 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 8 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 9 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 10 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 11 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 12 -SlotId 2 -modifypresent
Get-UcsFabricServerCloud -Id B | Add-UcsServerPort -AdminState enabled -PortId 13 -SlotId 2 -modifypresent

##########################
# Set UCS Admin Settings #
##########################
Get-UcsNativeAuth | Set-UcsNativeAuth -ConLogin local -DefLogin local -DefRolePolicy no-login -Force
if ($dns_1) {Add-UcsDnsServer -Name $dns_1 -modifypresent}
if ($dns_2) {Add-UcsDnsServer -Name $dns_2 -modifypresent} 
#Set-UcsTimezone -Timezone $timezone -Force
if ($ntp_1) {Add-UcsNtpServer -Name $ntp_1 -modifypresent}
if ($ntp_2) {Add-UcsNtpServer -Name $ntp_2 -modifypresent}

#########################################################
# Remove default Server, UUID, WWNN, WWPN and MAC pools #
#########################################################
Get-UcsServerPool -Name default -LimitScope | Remove-UcsServerPool -Force
Get-UcsUuidSuffixPool -Name default -LimitScope | Remove-UcsUuidSuffixPool -Force
Get-UcsWwnPool -Name node-default -LimitScope | Remove-UcsWwnPool -Force
Get-UcsWwnPool -Name default -LimitScope | Remove-UcsWwnPool -Force
Get-UcsMacPool -Name default -LimitScope | Remove-UcsMacPool -Force
Get-UcsManagedObject -Dn org-root/iqn-pool-default | Remove-UcsManagedObject -Force
Get-UcsManagedObject -DN org-root/ip-pool-iscsi-initiator-pool | Remove-UcsManagedObject -Force

############################
# Create LAN Port-Channels #
############################
$mo = Get-UcsfiLanCloud -Id A | Add-UcsUplinkPortChannel -AdminState disabled -Name VPC_ESA_103_A -PortId 103 -ModifyPresent
$mo_1 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 29 -SlotId 1
$mo_2 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 30 -SlotId 1
$mo_3 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 31 -SlotId 1
$mo_4 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 32 -SlotId 1
$mo_5 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 33 -SlotId 1
$mo_6 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 34 -SlotId 1
$mo_7 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 35 -SlotId 1
$mo_8 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 36 -SlotId 1
$mo_9 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 37 -SlotId 1
$mo_10 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 38 -SlotId 1
$mo_11 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 39 -SlotId 1
$mo_12 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 40 -SlotId 1

$mo = Get-UcsfiLanCloud -Id A | Add-UcsUplinkPortChannel -AdminState disabled -Name VPC_INT_108_A -PortId 108 -ModifyPresent
$mo_1 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 13 -SlotId 3
$mo_2 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 14 -SlotId 3
$mo_3 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 15 -SlotId 3
$mo_4 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 16 -SlotId 3
$mo_5 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 1 -SlotId 4
$mo_6 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 2 -SlotId 4
$mo_7 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 3 -SlotId 4
$mo_8 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 4 -SlotId 4
$mo_9 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 5 -SlotId 4
$mo_10 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 6 -SlotId 4
$mo_11 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 7 -SlotId 4
$mo_12 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 8 -SlotId 4

$mo = Get-UcsfiLanCloud -Id B | Add-UcsUplinkPortChannel -AdminState disabled -Name VPC_ESA_104_B -PortId 104 -ModifyPresent
$mo_1 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 29 -SlotId 1
$mo_2 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 30 -SlotId 1
$mo_3 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 31 -SlotId 1
$mo_4 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 32 -SlotId 1
$mo_5 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 33 -SlotId 1
$mo_6 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 34 -SlotId 1
$mo_7 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 35 -SlotId 1
$mo_8 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 36 -SlotId 1
$mo_9 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 37 -SlotId 1
$mo_10 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 38 -SlotId 1
$mo_11 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 39 -SlotId 1
$mo_12 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 40 -SlotId 1

$mo = Get-UcsfiLanCloud -Id B | Add-UcsUplinkPortChannel -AdminState disabled -Name VPC_INT_108_B -PortId 108 -ModifyPresent
$mo_1 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 13 -SlotId 3
$mo_2 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 14 -SlotId 3
$mo_3 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 15 -SlotId 3
$mo_4 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 16 -SlotId 3
$mo_5 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 1 -SlotId 4
$mo_6 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 2 -SlotId 4
$mo_7 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 3 -SlotId 4
$mo_8 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 4 -SlotId 4
$mo_9 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 5 -SlotId 4
$mo_10 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 6 -SlotId 4
$mo_11 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 7 -SlotId 4
$mo_12 = $mo | Add-UcsUplinkPortChannelMember -ModifyPresent -AdminState enabled -PortId 8 -SlotId 4


################
# Create VSANs #
################
Get-UcsfiSanCloud -Id A | Add-UcsVsan -FcoeVlan $fcoe_vlan_a -Id $vsan_a_id -Name $vsan_a_name -ModifyPresent
Get-UcsfiSanCloud -Id B | Add-UcsVsan -FcoeVlan $fcoe_vlan_b -Id $vsan_b_id -Name $vsan_b_name -ModifyPresent

####################
# Setup Global QoS #
####################
Start-UcsTransaction
get-ucsqosclass platinum | set-ucsqosclass -mtu 1500 -Force -Adminstate disabled
get-ucsqosclass gold | set-ucsqosclass -mtu 1500 -Force -Adminstate disabled
get-ucsqosclass silver | set-ucsqosclass -mtu 9000 -Force -Adminstate enabled
get-ucsqosclass bronze | set-ucsqosclass -mtu 9000 -Force -Adminstate enabled
get-ucsqosclass best-effort | set-ucsqosclass -mtu 1500 -Force -Adminstate enabled
Complete-UcsTransaction

##################
# Create Sub-Org #
##################

$root_org = Get-UcsOrg -Level root
$result = Get-UcsOrg -Org $root_org -Name $organization
if(!$result) {
    $our_org = Add-UcsOrg -Org $root_org -Name $organization
} else {
    Write-host "Organization $organization already exists, skipping"
    $our_org = $result
}


#####################
# Creating Policies #
#####################

######################
# Setup QoS Policies #
######################
$mo = Get-UcsOrg -Name $organization | Add-UcsQosPolicy -Name BE  -ModifyPresent
$mo_1 = $mo | Add-UcsVnicEgressPolicy -ModifyPresent -Burst 10240 -HostControl none -Prio "best-effort" -Rate line-rate

$mo = Get-UcsOrg -Name $organization | Add-UcsQosPolicy -Name Bronze -ModifyPresent
$mo_1 = $mo | Add-UcsVnicEgressPolicy -ModifyPresent -Burst 10240 -HostControl none -Prio "bronze" -Rate line-rate

$mo = Get-UcsOrg -Name $organization | Add-UcsQosPolicy -Name Gold -ModifyPresent
$mo_1 = $mo | Add-UcsVnicEgressPolicy -ModifyPresent -Burst 10240 -HostControl none -Prio "gold" -Rate line-rate

$mo = Get-UcsOrg -Name $organization | Add-UcsQosPolicy -Name Platinum -ModifyPresent
$mo_1 = $mo | Add-UcsVnicEgressPolicy -ModifyPresent -Burst 10240 -HostControl none -Prio "platinum" -Rate line-rate

$mo = Get-UcsOrg -Name $organization | Add-UcsQosPolicy -Name Silver -ModifyPresent
$mo_1 = $mo | Add-UcsVnicEgressPolicy -ModifyPresent -Burst 10240 -HostControl none -Prio "silver" -Rate line-rate


###############################################
# Create Network Control Policy to Enable CDP #
###############################################
$mo = Get-UcsOrg -Level root  | Add-UcsNetworkControlPolicy -Cdp enabled -MacRegisterMode only-native-vlan -Name cdp-enable -UplinkFailAction link-down -ModifyPresent
$mo_1 = $mo | Add-UcsPortSecurityConfig -ModifyPresent -Forge allow


################
# Create VLANs #
################

$VLANList=IMPORT-CSV .\VLANs.csv
FOREACH ($line in $VLANList) {Get-UcsLanCloud | Add-UcsVlan -DefaultNet no -Id $line.VLAN_NUMBER -Name $line.VLAN_NAME -ModifyPresent}


############################
# Create Local Disk Policy #
############################
Get-UcsOrg -Name $organization  | Add-UcsLocalDiskConfigPolicy -Descr "For servers without local disks" -Mode any-configuration -Name any-config -ProtectConfig no
Get-UcsOrg -Name $organization  | Add-UcsLocalDiskConfigPolicy -Descr "For servers with two local disks" -Mode raid-mirrored -Name RAID-1 -ProtectConfig no

#############################
# Create maintenance policy #
#############################
Get-UcsOrg -Name $organization  | Add-UcsMaintenancePolicy -Descr "User acknowledge is required to reboot a server after a disruptive change" -Name user-acknowledge -UptimeDisr user-ack

#################################
# Create disk/BIOS Scrub Policy #
#################################
Get-UcsOrg -Name $organization  | Add-UcsScrubPolicy -BiosSettingsScrub no -DiskScrub no -Name no-scrub

################################
# Create a no-power cap policy #
################################
Get-UcsOrg -Name $organization  | Add-UcsPowerPolicy -Name no-power-cap -Prio no-cap

#####################################
# Create vNIC/vHBA Placement Policy #
#####################################
$mo = Get-UcsOrg -Name $organization  | Add-UcsPlacementPolicy -Descr "For Half-width blades" -Name b200-b230
$mo_1 = $mo | Add-UcsFabricVCon -ModifyPresent -Fabric NONE -Id 1 -Placement physical -Select all -Share shared -Transport ethernet,fc

###############################
# Create SAN Boot Policies    #
###############################
$bp = Add-UcsBootPolicy -Org $organization -Name $boot_policy_fab_a_name -EnforceVnicName yes
$bp | Add-UcsLsBootVirtualMedia -Access "read-only" -Order "1"
$bootstorage = $bp | Add-UcsLsbootStorage -ModifyPresent -Order "2"
$bootsanimage = $bootstorage | Add-UcsLsbootSanImage -Type "primary" -VnicName $vhba_template_a_name
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "primary" -Wwn "50:06:01:66:47:20:75:94"
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "secondary" -Wwn "50:06:01:6F:47:20:75:94"

$bootsanimage = $bootstorage | Add-UcsLsbootSanImage -Type "secondary" -VnicName $vhba_template_b_name
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "primary" -Wwn "50:06:01:67:47:20:75:94"
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "secondary" -Wwn "50:06:01:6E:47:20:75:94"

$bp = Add-UcsBootPolicy -Org $organization -Name $boot_policy_fab_b_name -EnforceVnicName yes
$bp | Add-UcsLsBootVirtualMedia -Access "read-only" -Order "1"
$bootstorage = $bp | Add-UcsLsbootStorage -ModifyPresent -Order "2"
$bootsanimage = $bootstorage | Add-UcsLsbootSanImage -Type "primary" -VnicName $vhba_template_b_name
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "primary" -Wwn "50:06:01:65:47:20:75:94"
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "secondary" -Wwn "50:06:01:6C:47:20:75:94"

$bootsanimage = $bootstorage | Add-UcsLsbootSanImage -Type "secondary" -VnicName $vhba_template_a_name
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "primary" -Wwn "50:06:01:64:47:20:75:94"
$bootsanimage | Add-UcsLsbootSanImagePath -Lun 0 -Type "secondary" -Wwn "50:06:01:6D:47:20:75:94"



################
# Create Pools #
################

# UUID Pool
$uuidPool = Add-UcsUuidSuffixPool -Org $organization -Name $uuid_name -AssignmentOrder "sequential" -Descr $uuid_descr -Prefix derived  -ModifyPresent
Add-UcsUuidSuffixBlock -UuidSuffixPool $uuidPool -From $uuid_from -To $uuid_to

## MAC Pools
$macPool = Add-UcsMacPool -Org $organization -Name $mac_pool_esx_mgmt_a_name -AssignmentOrder "sequential" -Descr $mac_pool_esx_mgmt_name
Add-UcsMacMemberBlock -MacPool $macPool -From $mac_pool_esx_mgmt_a_from -To $mac_pool_esx_mgmt_a_to

$macPool = Add-UcsMacPool -Org $organization -Name $mac_pool_esx_mgmt_b_name -AssignmentOrder "sequential" -Descr $mac_pool_esx_mgmt_name
Add-UcsMacMemberBlock -MacPool $macPool -From $mac_pool_esx_mgmt_b_from -To $mac_pool_esx_mgmt_b_to

$macPool = Add-UcsMacPool -Org $organization -Name $mac_pool_esa_vmdata_a_name -AssignmentOrder "sequential" -Descr $mac_pool_esa_vmdata_name
Add-UcsMacMemberBlock -MacPool $macPool -From $mac_pool_esa_vmdata_a_from -To $mac_pool_esa_vmdata_a_to

$macPool = Add-UcsMacPool -Org $organization -Name $mac_pool_esa_vmdata_b_name -AssignmentOrder "sequential" -Descr $mac_pool_esa_vmdata_name
Add-UcsMacMemberBlock -MacPool $macPool -From $mac_pool_esa_vmdata_b_from -To $mac_pool_esa_vmdata_b_to

$macPool = Add-UcsMacPool -Org $organization -Name $mac_pool_int_vmdata_a_name -AssignmentOrder "sequential" -Descr $mac_pool_int_vmdata_name
Add-UcsMacMemberBlock -MacPool $macPool -From $mac_pool_int_vmdata_a_from -To $mac_pool_int_vmdata_a_to

$macPool = Add-UcsMacPool -Org $organization -Name $mac_pool_int_vmdata_b_name -AssignmentOrder "sequential" -Descr $mac_pool_int_vmdata_name
Add-UcsMacMemberBlock -MacPool $macPool -From $mac_pool_int_vmdata_b_from -To $mac_pool_int_vmdata_b_to

$macPool = Add-UcsMacPool -Org $organization -Name $mac_pool_windows_a_name -AssignmentOrder "sequential" -Descr $mac_pool_windows_name
Add-UcsMacMemberBlock -MacPool $macPool -From $mac_pool_windows_a_from -To $mac_pool_windows_a_to

$macPool = Add-UcsMacPool -Org $organization -Name $mac_pool_windows_b_name -AssignmentOrder "sequential" -Descr $mac_pool_windows_name
Add-UcsMacMemberBlock -MacPool $macPool -From $mac_pool_windows_b_from -To $mac_pool_windows_b_to

$macPool = Add-UcsMacPool -Org $organization -Name $mac_pool_cseries_a_name -AssignmentOrder "sequential" -Descr $mac_pool_cseries_name
Add-UcsMacMemberBlock -MacPool $macPool -From $mac_pool_cseries_a_from -To $mac_pool_cseries_a_to

$macPool = Add-UcsMacPool -Org $organization -Name $mac_pool_cseries_b_name -AssignmentOrder "sequential" -Descr $mac_pool_cseries_name
Add-UcsMacMemberBlock -MacPool $macPool -From $mac_pool_cseries_b_from -To $mac_pool_cseries_b_to


###create WWNN pools####################
$wwnPool = Add-UcsWwnPool -Org $organization -Name $wwnn_pool_name -AssignmentOrder "sequential" -Purpose "node-wwn-assignment"
Add-UcsWwnMemberBlock -wwnPool $wwnPool -From $wwnn_pool_from -To $wwnn_pool_to

###create WWPN pools#########################
$wwnPool = Add-UcsWwnPool -Org $organization -Name $wwpn_pool_a_name -AssignmentOrder "sequential" -Purpose "port-wwn-assignment" -Descr $wwpn_pool_name
Add-UcsWwnMemberBlock -wwnPool $wwnPool -From $wwpn_a_from -To $wwpn_a_to

$wwnPool = Add-UcsWwnPool -Org $organization -Name $wwpn_pool_b_name -AssignmentOrder "sequential" -Purpose "port-wwn-assignment" -Descr $wwpn_pool_name
Add-UcsWwnMemberBlock -wwnPool $wwnPool -From $wwpn_b_from -To $wwpn_b_to


#########################
# Create vNIC Templates #
#########################
$mo = Get-UcsOrg -Name $organization  | Add-UcsVnicTemplate -IdentPoolName $mac_pool_esx_mgmt_a_name -Mtu 1500 -Name $vnic_template_a_esxi_mgmt_name -NwCtrlPolicyName cdp-enable -QosPolicyName BE -StatsPolicyName default -SwitchId A -TemplType updating-template

$mo = Get-UcsOrg -Name $organization  | Add-UcsVnicTemplate -IdentPoolName $mac_pool_esx_mgmt_b_name -Mtu 1500 -Name $vnic_template_b_esxi_mgmt_name -NwCtrlPolicyName cdp-enable -QosPolicyName BE -StatsPolicyName default -SwitchId B -TemplType updating-template

$mo = Get-UcsOrg -Name $organization  | Add-UcsVnicTemplate -IdentPoolName $mac_pool_esa_vmdata_a_name -Mtu 1500 -Name $vnic_template_a_esa_vmdata_name -NwCtrlPolicyName cdp-enable -QosPolicyName BE -StatsPolicyName default -SwitchId A -TemplType updating-template

$mo = Get-UcsOrg -Name $organization  | Add-UcsVnicTemplate -IdentPoolName $mac_pool_esa_vmdata_b_name -Mtu 1500 -Name $vnic_template_b_esa_vmdata_name -NwCtrlPolicyName cdp-enable -QosPolicyName BE -StatsPolicyName default -SwitchId B -TemplType updating-template

$mo = Get-UcsOrg -Name $organization  | Add-UcsVnicTemplate -IdentPoolName $mac_pool_int_vmdata_a_name -Mtu 1500 -Name $vnic_template_a_int_vmdata_name -NwCtrlPolicyName cdp-enable -QosPolicyName BE -StatsPolicyName default -SwitchId A -TemplType updating-template

$mo = Get-UcsOrg -Name $organization  | Add-UcsVnicTemplate -IdentPoolName $mac_pool_int_vmdata_b_name -Mtu 1500 -Name $vnic_template_b_int_vmdata_name -NwCtrlPolicyName cdp-enable -QosPolicyName BE -StatsPolicyName default -SwitchId B -TemplType updating-template

$mo = Get-UcsOrg -Name $organization  | Add-UcsVnicTemplate -IdentPoolName $mac_pool_windows_a_name -Mtu 1500 -Name $vnic_template_a_windows_name -NwCtrlPolicyName cdp-enable -QosPolicyName BE -StatsPolicyName default -SwitchId A -TemplType updating-template

$mo = Get-UcsOrg -Name $organization  | Add-UcsVnicTemplate -IdentPoolName $mac_pool_windows_b_name -Mtu 1500 -Name $vnic_template_b_windows_name -NwCtrlPolicyName cdp-enable -QosPolicyName BE -StatsPolicyName default -SwitchId B -TemplType updating-template

$mo = Get-UcsOrg -Name $organization  | Add-UcsVnicTemplate -IdentPoolName $mac_pool_cseries_a_name -Mtu 1500 -Name $vnic_template_a_cseries_name -NwCtrlPolicyName cdp-enable -QosPolicyName BE -StatsPolicyName default -SwitchId A -TemplType updating-template

$mo = Get-UcsOrg -Name $organization  | Add-UcsVnicTemplate -IdentPoolName $mac_pool_cseries_b_name -Mtu 1500 -Name $vnic_template_b_cseries_name -NwCtrlPolicyName cdp-enable -QosPolicyName BE -StatsPolicyName default -SwitchId B -TemplType updating-template

##########################
# Create vHBA Templates #
##########################
$mo = Get-UcsOrg -Name $organization  | Add-UcsVhbaTemplate -IdentPoolName $wwpn_pool_a_name -MaxDataFieldSize 2048 -Name $vhba_template_a_name -StatsPolicyName default -SwitchId A -TemplType updating-template
$mo_1 = $mo | Add-UcsVhbaInterface -ModifyPresent -Name $vsan_a_name

$mo = Get-UcsOrg -Name $organization  | Add-UcsVhbaTemplate -IdentPoolName $wwpn_pool_b_name -MaxDataFieldSize 2048 -Name $vhba_template_b_name -StatsPolicyName default -SwitchId B -TemplType updating-template
$mo_1 = $mo | Add-UcsVhbaInterface -ModifyPresent -Name $vsan_b_name


########################################
# Create Service Profile Templates     #
########################################
#$mo = Get-UcsOrg -Name $organization  | Add-UcsServiceProfile -BootPolicyName $boot_policy_name -Descr "Service Profile Template for VMware ESXi hosts" -ExtIPState pooled -IdentPoolName $uuid_name -LocalDiskPolicyName any-config -MaintPolicyName user-acknowledge -Name $profile_template_esx_name -PowerPolicyName default -ScrubPolicyName no-scrub -StatsPolicyName default -Type updating-template -VconProfileName b200-b230
#$mo_1 = $mo | Add-UcsVnic -AdaptorProfileName VMWare -Addr derived -AdminVcon 1 -Mtu 1500 -Name $vnic_template_a_esxi_mgmt_name -NwTemplName $vnic_template_a_esxi_mgmt_name -Order 1 -StatsPolicyName default -SwitchId A
#$mo_2 = $mo | Add-UcsVnic -AdaptorProfileName VMWare -Addr derived -AdminVcon 1 -Mtu 1500 -Name $vnic_template_b_esxi_mgmt_name -NwTemplName $vnic_template_b_esxi_mgmt_name -Order 2 -StatsPolicyName default -SwitchId B
#$mo_3 = $mo | Add-UcsVnic -AdaptorProfileName VMWare -Addr derived -AdminVcon 1 -Mtu 1500 -Name $vnic_template_a_esa_vmdata_name -NwTemplName $vnic_template_b_esa_vmdata_name -Order 3 -StatsPolicyName default -SwitchId A
#$mo_4 = $mo | Add-UcsVnic -AdaptorProfileName VMWare -Addr derived -AdminVcon 1 -Mtu 1500 -Name $vnic_template_b_esa_vmdata_name -NwTemplName $vnic_template_b_esa_vmdata_name -Order 4 -StatsPolicyName default -SwitchId B
#$mo_5 = $mo | Add-UcsVnic -AdaptorProfileName VMWare -Addr derived -AdminVcon 1 -Mtu 1500 -Name $vnic_template_a_int_vmdata_name -NwTemplName $vnic_template_a_int_vmdata_name -Order 5 -StatsPolicyName default -SwitchId A
#$mo_6 = $mo | Add-UcsVnic -AdaptorProfileName VMWare -Addr derived -AdminVcon 1 -Mtu 1500 -Name $vnic_template_b_int_vmdata_name -NwTemplName $vnic_template_b_int_vmdata_name -Order 6 -StatsPolicyName default -SwitchId B
#$mo_7 = $mo | Add-UcsVnic -AdaptorProfileName VMWare -Addr derived -AdminVcon 1 -Mtu 1500 -Name $vnic_template_a_windows_name -NwTemplName $vnic_template_a_windows_name -Order 7 -StatsPolicyName default -SwitchId A
#$mo_8 = $mo | Add-UcsVnic -AdaptorProfileName VMWare -Addr derived -AdminVcon 1 -Mtu 1500 -Name $vnic_template_b_windows_name -NwTemplName $vnic_template_b_windows_name -Order 8 -StatsPolicyName default -SwitchId B
#$mo_9 = $mo | Add-UcsVnicFcNode -ModifyPresent -Addr pool-derived -IdentPoolName $wwnn_pool_name
#$mo_10 = $mo | Add-UcsVhba -AdaptorProfileName VMWare -Addr derived -AdminVcon 2 -MaxDataFieldSize 2048 -Name $vhba_template_a_name -NwTemplName $vhba_template_a_name -Order 7 -PersBind disabled -PersBindClear no -StatsPolicyName default -SwitchId A
#$mo_11 = $mo | Add-UcsVhba -AdaptorProfileName VMWare -Addr derived -AdminVcon 2 -MaxDataFieldSize 2048 -Name $vhba_template_b_name -NwTemplName $vhba_template_b_name -Order 8 -PersBind disabled -PersBindClear no -StatsPolicyName default -SwitchId B
#$mo_12 = $mo | Set-UcsServerPower -State admin-up -Force

#############################
# Creating Service Profiles #
#############################
#Get-UcsServiceProfile -Name $profile_template_esx_name -Org $organization | Add-UcsServiceProfileFromTemplate -Prefix $profile_esxi_prefix -Count 3 -DestinationOrg $organization

Stop-Transcript