# Cisco UCS PowerShell Script Automation
# Author: Drew Russell

import os


# region Intro Text
print ''
print 'Cisco UCS PowerShell Automation'
print 'Author: Drew Russell'
print 'Website: www.datacenterhandbook.com'
print ''
# endregion

# region Global Functions
def powershell_create():

    global project_name
    global power_shell

    power_shell = open(project_name+'.ps1', "w")

    #User Enters UCS Credentials
    print ''
    print 'Cisco UCS Login Credentials: '

    ucs_address = raw_input('IP Address: ')

    while len(ucs_address) < 1 or has_numbers(ucs_address) is False:
        print ''
        print '*** Error: Please enter a valid IP Address *** '
        print ''
        ucs_address = raw_input('IP Address: ')

    ucs_user_name = raw_input('User Name: ')

    while len(ucs_user_name) < 1 or has_numbers(ucs_user_name) is True:
        print ''
        print '*** Error: User name is a mandatory field and may contain only letters ***'
        print ''
        ucs_user_name = raw_input('User Name: ')

    ucs_password = raw_input('Password: ')
    #Encrypted Password
    # ucs_password = getpass.getpass('Password: ')

    while len(ucs_password) < 1:
        print ''
        print '*** Error: Password is a Mandatory Field ***'
        print ''
        ucs_password = raw_input('Password: ')
        #Encrypted Password
        # ucs_password = getpass.getpass('Password: ')

    #Define the credentials in PowerShell
    power_shell.write(str('$ucsAddress = "%s" ' % (ucs_address)) + "\n")
    power_shell.write(str('$ucsUserName = "%s"' % (ucs_user_name)) + "\n")
    power_shell.write(str('$ucsPassword = "%s"' % (ucs_password)) + "\n")

    # Import the UCS PowerTool module
    power_shell.write(str('Import-Module "C:\Program Files (x86)\Cisco\Cisco UCS PowerTool\Modules\CiscoUcsPS\CiscoUcsPS.psd1"') + "\n")

    # The UCS connection requires a PSCredential to login so convert password to plaintext
    power_shell.write(str('$ucsPassword = ConvertTo-SecureString -String $ucsPassword -AsPlainText -Force') + "\n")
    power_shell.write(str('$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $ucsUserName, $ucsPassword') + "\n")

    # Log into to UCS
    power_shell.write(str('$ucsAddress = Connect-Ucs $ucsAddress -Credential $cred') + "\n")

    power_shell.write(str('Start-UcsTransaction') + "\n")


def powershell_final():
    global power_shell
    global project_name

    #Open Power Shell Script and count the number of lines
    power_shell = open(project_name+'.ps1', "r")
    count = 0
    for line in power_shell:
        count = count + 1

    #Read of the lines in the script and commit to memory
    power_shell = open(project_name+'.ps1', "r+")
    data = power_shell.readlines()

    power_shell_transaction_number = 1


    # add $mo_(x) to each line
    for power_shell_update in range(8, (int(count)) ):
            data[power_shell_update] = '$mo_' + str(power_shell_transaction_number) +' = ' + data[power_shell_update]
            power_shell_transaction_number += 1

    # Save the new lines
    for power_shell_update in range(1, (int(count)) ):
        power_shell = open(project_name+'.ps1', "w")
        power_shell.writelines(data)

    # Complete the PowerShell Config and Disconnect from UCS
    power_shell = open(project_name+'.ps1', "a")
    power_shell.write(str('Complete-UcsTransaction') + "\n")
    power_shell.write(str('Disconnect-Ucs') + "\n")
    power_shell.write(str('') + "\n")
    power_shell.close()


def has_numbers(input_string):
    return any(char.isdigit() for char in input_string)
#endregion

#region VLAN Functions


def vlan_configuration():
# region VLAN Configuration
        print ''
        option_vlan = raw_input('Would you like to configure VLANS (yes/no): ').lower()

        while option_vlan not in ['yes', 'y', 'no', 'n']:
            print ''
            print '*** Error: Please enter "Yes or "No" ***'
            print ''
            option_vlan = raw_input('Would you like to configure VLANS (yes/no): ').lower()

        if option_vlan in ['yes', 'y']:
            print ''
            print '**** VLAN Configuration ****'
            print ''
            print ''
            print 'Cisco UCS has the following VLAN configuration options:'
            print ''
            print ' * Global (The VLANs apply to both fabrics and use the same configuration parameters in both cases)'
            print ' * Fabric A (The VLANs only apply to Fabric A)'
            print ' * Fabric B (The VLAN only apply to fabric B)'
            print ''
            vlan_type = raw_input('Which type of VLAN would you like to create (Global/Fabric A/Fabric B): ').lower()
            print ''

            while vlan_type not in ['global', 'fabric a', 'fabric b']:
                print ''
                print '*** Error: Please enter "Global", "Fabric A", or "Fabric B". *** '
                print ''
                vlan_type = raw_input('Which type of VLAN would you like to create (Global/Fabric A/Fabric B): ').lower()
                print ''

            #Prints PowerShell code to file depending on user input
            if vlan_type in ['global']:
                vlan_input()
                powershell_vlan_global()

            elif vlan_type in ['fabric a']:
                print ''
                vlan_input()
                powershell_vlan_fabric('a')
                vlan_second_fabric('b')

            elif vlan_type in ['fabric b']:
                print ''
                vlan_input()
                powershell_vlan_fabric('b')
                vlan_second_fabric('a')

        while option_vlan in ['no', 'n']:
                break


def vlan_input():
    global vlan_count
    global vlan_name_list
    global vlan_number_list
    global vlan_name
    global vlan_number
    vlan_count = raw_input('Enter the number of VLANs you would like to create: ')

    #Verify that VLAN is populated and contains only numbers
    while len(vlan_count) < 1 or has_numbers(vlan_count) is False:
            print ''
            print '*** Error: VLAN Count is a mandatory field and may contain only numbers ***'
            print ''
            vlan_count = raw_input('Enter the number of VLANs you would like to create: ')

    print ''
    vlan_name_list = []
    vlan_number_list = []
    for user_vlan_data in range(1, (int(vlan_count)+1)):
        print 'VLAN %d Configuration: ' % user_vlan_data
        vlan_name = raw_input('Name: ')

        #Verify that the VLAN Name field is populated and does not contain any numbers
        has_numbers(vlan_name)
        while len(vlan_name) < 1 or has_numbers(vlan_name) is True:
            print ''
            print '*** Error: VLAN Name is a mandatory field and may not contain numbers ***'
            print ''
            print 'VLAN %d Configuration: ' % user_vlan_data
            vlan_name = raw_input('Name: ')

        vlan_number = raw_input('Number (ID): ')

        #Verify that the VLAN Number field is populated contains only numbers
        has_numbers(vlan_number)
        while len(vlan_number) < 1 or has_numbers(vlan_number) is False:
            print ''
            print '*** Error: VLAN Number(ID) is a mandatory field and may contain only numbers ***'
            print ''
            print 'VLAN %d Configuration: ' % user_vlan_data
            print 'Name: ' + str(vlan_name)
            vlan_number = raw_input('Number (ID): ')
        #

        print ''
        vlan_name_list.append(vlan_name)
        vlan_number_list.append(vlan_number)


def vlan_second_fabric(c):
    vlan_second_fabric_select = 'Would you like to configure VLANs for Fabric %s (yes/no): ' % (str(c.upper()))
    option_vlan_second_fabric = raw_input(vlan_second_fabric_select).lower()

    while option_vlan_second_fabric not in ['yes', 'y', 'no', 'n']:
        print '*** Error: Please enter "Yes or "No" ***'
        print ''
        option_vlan_second_fabric = raw_input(vlan_second_fabric_select).lower()

    if option_vlan_second_fabric in ['yes', 'y']:
        print''
        vlan_input()
        powershell_vlan_fabric(c)

    while option_vlan_second_fabric in ['no', '']:
        break


def powershell_vlan_global():
    global power_shell
    global vlan_count
    global vlan_name_list
    global vlan_number_list

    for script_vlan_output in range(int(vlan_count)):
                    power_shell = open(project_name+'.ps1', "a")
                    power_shell.write(str('Get-UcsLanCloud | Add-UcsVlan -Name %s -Id %s' % (vlan_name_list[script_vlan_output], vlan_number_list[script_vlan_output])) + "\n")


def powershell_vlan_fabric(a):
    global power_shell
    global vlan_count
    global vlan_name_list
    global vlan_number_list
    for script_vlan_output in range(int(vlan_count)):
                        power_shell = open(project_name+'.ps1', "a")
                        power_shell.write(str('Get-UcsFiLanCloud -Id %s | Add-UcsVlan -Name %s -Id %s' % (a.upper(), vlan_name_list[script_vlan_output], vlan_number_list[script_vlan_output])) + "\n")

#endregion

# region Network Control Policy Functions


def network_control_policy_configuration():
# region Network Control Policy Configuration
        print ''
        option_network_control_policy = raw_input('Would you like to create a Network Control Policy (yes/no): ').lower()

        while option_network_control_policy not in ['yes', 'y', 'no', 'n']:
            print ''
            print '*** Error: Please enter "Yes" or "No" ***'
            print ''
            option_network_control_policy = raw_input('Would you like to create a Network Control Policy : ').lower()

        if option_network_control_policy in ['yes', 'y']:
            print ''
            print '**** Network Control Policy Configuration ****'
            print ''
            print ''
            print 'The following options are available for each Network Control Policy: '
            print ''
            print ' * Cisco Discovery Policy (CDP)'
            print ' * MAC Register Mode'
            print ' * Action on Uplink Fail'
            print ' * MAC Security'
            print ''

            network_control_policy_input()
            powershell_network_control_policy()

        while option_network_control_policy in ['no', 'n']:
                break


def network_control_policy_input():
    global network_control_policy_name_list
    global network_control_policy_cdp_list
    global network_control_policy_mac_register_mode_list
    global network_control_policy_uplink_fail_list
    global network_control_policy_mac_security_list
    #
    global network_control_policy_count
    global network_control_policy_name
    global network_control_policy_cdp
    global network_control_policy_uplink_fail
    global network_control_policy_mac_security

    network_control_policy_count = raw_input('Enter the number of unique Network Control Policies you would like to create: ')

    #Verify that VLAN is populated and contains only numbers
    while len(network_control_policy_count) < 1 or has_numbers(network_control_policy_count) is False:
            print ''
            print '*** Error: Please enter a valid number ***'
            print ''
            network_control_policy_count = raw_input('Enter the number of Network Control Policies you would like to create: ')


    print ''
    network_control_policy_name_list = []
    network_control_policy_cdp_list = []
    network_control_policy_mac_register_mode_list = []
    network_control_policy_uplink_fail_list = []
    network_control_policy_mac_security_list = []

    for user_network_control_policy_data in range(1, (int(network_control_policy_count)+1) ):
        print 'Network Control Policy %d Configuration: ' % user_network_control_policy_data
        network_control_policy_name = raw_input('Name: ')

        #Verify that the  Name field is populated and does not contain any numbers
        has_numbers(network_control_policy_name)
        while len(network_control_policy_name) < 1 or has_numbers(network_control_policy_name) is True:
            print ''
            print '*** Error: Network Control Policy Name is a mandatory field and may not contain numbers ***'
            print ''
            print 'Network Control Policy %d Configuration: ' % user_network_control_policy_data
            network_control_policy_name = raw_input('Name: ')

        #Verify that the  CDP field is populated with either enabled or disabled
        print ''
        print '*** CDP Default is Disabled ***'
        network_control_policy_cdp = raw_input('Would you like CDP to be Enabled or Disabled? ').lower()

        while network_control_policy_cdp not in ['enabled', 'disabled']:
            print ''
            print '*** Error: Please enter "Enabled" or "Disabled" ***'
            print ''
            network_control_policy_cdp = raw_input('Would you like CDP to be Enabled or Disabled? ').lower()


        #Verify that the Mac Register Mode field is populated with either native or host
        print ''
        print '*** MAC Register Mode Default is Only Native Vlan ***'
        network_control_policy_mac_register_mode = raw_input('Would you like the MAC Register Mode be set to "Only Native Vlan" or "All Host Vlan" (native/host) ').lower()

        while network_control_policy_mac_register_mode not in ['native', 'host']:
                print ''
                print '*** Error: Please enter "Native" or "Host" ***'
                print ''
                network_control_policy_mac_register_mode = raw_input('Would you like the MAC Register Mode to be set to "Only Native Vlan" or "All Host Vlan" (native/host)? ').lower()

        #Set the Network Control Policy to the correct PowerShell Formatting
        if network_control_policy_mac_register_mode == "native":
                network_control_policy_mac_register_mode = 'only-native-vlan'
        elif network_control_policy_mac_register_mode == 'host':
                network_control_policy_mac_register_mode = 'all-host-vlans'

        #Verify that the  Action on Uplink Fail field is populated with link-down or warning
        print ''
        print '*** Action on Uplink Fail Default is Link Down ***'
        network_control_policy_uplink_fail = raw_input('Would you like the Action on Uplink Fail be set to Link Down or Warning (down/warning)? ').lower()

        while network_control_policy_uplink_fail not in ['down', 'warning']:
            print ''
            print '*** Error: Please enter "Down" or "Warning" ***'
            print ''
            network_control_policy_uplink_fail = raw_input('Would you like the Action on Uplink Fail be set to Link Down or Warning (down/warning)? ').lower()

        #set the proper formatting for link down
        if network_control_policy_uplink_fail == "down":
                network_control_policy_uplink_fail = 'link-down'

        #Verify that the  MAC Security field is populated with allow or deny
        print ''
        print '*** MAC Security Default is Allow ***'
        network_control_policy_mac_security = raw_input('Would you like MAC Security to be set to Allow or Deny? ').lower()

        while network_control_policy_mac_security not in ['allow', 'deny']:
            print ''
            print '*** Error: Please enter "Allow" or "Deny" ***'
            print ''
            network_control_policy_mac_security = raw_input('Would you like MAC Security to be set to Allow or Deny? ').lower()


        print ''
        network_control_policy_name_list.append(network_control_policy_name)
        network_control_policy_cdp_list.append(network_control_policy_cdp)
        network_control_policy_mac_register_mode_list.append(network_control_policy_mac_register_mode)
        network_control_policy_uplink_fail_list.append(network_control_policy_uplink_fail)
        network_control_policy_mac_security_list.append(network_control_policy_mac_security)


def powershell_network_control_policy():
    global power_shell
    global network_control_policy_name_list
    global network_control_policy_cdp_list
    global network_control_policy_mac_register_mode_list
    global network_control_policy_uplink_fail_list
    global network_control_policy_mac_security_list
    for script_network_control_policy_output in range(int(network_control_policy_count)):
        power_shell = open(project_name+'.ps1', "a")
        power_shell.write(str('$network_policy = Get-UcsOrg -Level root | Add-UcsNetworkControlPolicy -Name %s -Cdp %s -MacRegisterMode %s -UplinkFailAction %s | Set-UcsPortSecurityConfig -Forge %s' % (network_control_policy_name_list[script_network_control_policy_output], network_control_policy_cdp_list[script_network_control_policy_output], network_control_policy_mac_register_mode_list[script_network_control_policy_output], network_control_policy_uplink_fail_list[script_network_control_policy_output], network_control_policy_mac_security_list[script_network_control_policy_output])) + "\n")


# endregion


# region Start Script

#Powershell Create
project_name = raw_input('Please enter a unique project name: ')

if len(project_name) < 1:
    print ''
    project_name = raw_input('Please enter a unique project name: ')
    powershell_create()

elif len(project_name) >= 1:
    powershell_create()


#Enter Configuration Options

vlan_configuration()

network_control_policy_configuration()


powershell_final()


# endregion


# region Exit Text
#Get the current directory
current_directory = str(os.getcwd())
print ''
print '********'
print ''
print 'The PowerShell Script %s.ps1 has been successfully exported to %s!' % (project_name, current_directory)
print ''
print '********'
# endregion







