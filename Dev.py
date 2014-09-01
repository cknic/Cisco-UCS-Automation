def network_control_policy_configuration():
# region Network Control Policy Configuration
        print ''
        option_network_control_policy = raw_input('Would you like to create a Network Control Policy (yes/no): ').lower()

        while option_network_control_policy not in ['yes', 'y', 'no', 'n']:
            print ''
            print '*** Error: Please enter "Yes or "No" ***'
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

def network_control_policy_input():
    global network_control_policy_count
    global network_control_policy_name_list
    global network_control_policy_mac_register_mode_list
    global network_control_uplink_fail_list
    global network_control_mac_security_fail_list
    global network_control_policy_name
    global network_control_policy_cdp
    global network_control_policy_mac_register_mode_list
    global network_control_policy_up_link_fail
    global network_control_policy_mac_security
    network_control_policy_count = raw_input('Enter the number of unique Network Control Policies you would like to create: ')

    #Verify that VLAN is populated and contains only numbers
    while len(network_control_policy_count) < 1 or has_numbers(network_control_policy_count) is False:
            print ''
            print '*** Error: Please enter a valid number ***'
            print ''
            network_control_policy_count = raw_input('Enter the number of Network Control Policies you would like to create: ')


    print ''
    network_control_policy_count = []
    network_control_policy_name_list = []
    network_control_policy_mac_register_mode_list = []
    network_control_uplink_fail_list = []
    network_control_mac_security_fail_list = []

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

        network_control_policy_cdp = raw_input('Would you like to enable the Cisco Discovery Protocol (CDP) (yes/no): ').lower()

        while network_control_policy_cdp not in ['yes', 'y', 'no', 'n']:
            print ''
            print '*** Error: Please enter "Yes or "No" ***'
            print ''
            network_control_policy_cdp = raw_input('Would you like to enable the Cisco Discovery Protocol (CDP): (yes/no) ').lower()


        #

        print ''
        vlan_name_list.append(vlan_name)
        vlan_number_list.append(vlan_number)



def has_numbers(input_string):
    return any(char.isdigit() for char in input_string)



network_control_policy_configuration()

network_control_policy_input()