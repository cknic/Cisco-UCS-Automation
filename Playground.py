import getpass

def has_numbers(input_string):
    return any(char.isdigit() for char in input_string)

ucs_password = getpass.getpass('Password: ')


while len(ucs_password) < 1:
    print ''
    print '*** Error: Password is a Mandatory Field ***'
    print ''
    ucs_password = getpass.getpass('Password: ')









