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

        while option_network_control_policy in ['no', 'n']:
                break

        network_control_policy_input()
        powershell_network_control_policy()

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
                network_control_policy_mac_register_mode = 'all-host-vlan'

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
    global network_control_policy_name_list
    global network_control_policy_cdp_list
    global network_control_policy_mac_register_mode_list
    global network_control_policy_uplink_fail_list
    global network_control_policy_mac_security_list
    for script_network_control_policy_output in range(int(network_control_policy_count)):
                    power_shell = open(project_name+'.ps1', "a")
                    power_shell.write(str('%s -MacRegisterMode –UplinkFailAction %s | Set-UcsPortSecurityConfig -Forge %s' % (network_control_policy_name_list[script_network_control_policy_output], network_control_policy_cdp_list[script_network_control_policy_output], network_control_policy_mac_register_mode_list[script_network_control_policy_output], network_control_policy_uplink_fail_list[script_network_control_policy_output], network_control_policy_mac_security_list[script_network_control_policy_output])) + "\n")


network_control_policy_configuration()

network_control_policy_input()