$ucsAddress = "10.255.140.38" 
$ucsUserName = "admin"
$ucsPassword = "WWTwwt1!"
Import-Module "C:\Program Files (x86)\Cisco\Cisco UCS PowerTool\Modules\CiscoUcsPS\CiscoUcsPS.psd1"
$ucsPassword = ConvertTo-SecureString -String $ucsPassword -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $ucsUserName, $ucsPassword
$ucsAddress = Connect-Ucs $ucsAddress -Credential $cred
Start-UcsTransaction
$mo_1 = Get-UcsFiLanCloud -Id A | Add-UcsVlan -Name vMotion -Id 100
$mo_2 = Get-UcsFiLanCloud -Id A | Add-UcsVlan -Name Storage -Id 200
$mo_3 = $network_policy = Get-UcsOrg -Level root | Add-UcsNetworkControlPolicy -Name network_control -Cdp enabled -MacRegisterMode only-native-vlan -UplinkFailAction warning | Set-UcsPortSecurityConfig -Forge allow
$mo_4 = $network_policy = Get-UcsOrg -Level root | Add-UcsNetworkControlPolicy -Name CDP_Disabled -Cdp disabled -MacRegisterMode only-native-vlan -UplinkFailAction link-down | Set-UcsPortSecurityConfig -Forge deny
Complete-UcsTransaction
