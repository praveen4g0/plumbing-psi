import time
import os
import re
import string
import random
import subprocess
import json
import argparse
import codecs

parser = argparse.ArgumentParser()
parser.add_argument('--operating_system', type=str, help='Operating system you want to create and run tests',
                    choices=['windows10', 'rhel8', 'fedora31', 'ubuntu16'],
                    required=True)
parser.add_argument('--network', type=str, default='provider_net_cci_9',
                    help='Name or ID of a network to attach this instance to (Default Value: provider_net_cci_9)')
parser.add_argument('--keypair_name', type=str, help='Keypair name to create VM', required=True)
parser.add_argument('--private_key_location', type=str, help='private key location', required=True)
parser.add_argument('--test_type', help='Type of test you want to run', required=True,
                    choices=['upstream', 'downstream'])
parser.add_argument('--ocp_username', type=str, help='OCP cluster username or set environment variable OCP_USERNAME')
parser.add_argument('--ocp_password', type=str, help='OCP cluster password or set environment variable OCP_PASSWORD')
parser.add_argument('--ocp_server_address', type=str,
                    help='OCP cluster server address or set environment variable OCP_SERVER_ADDRESS')
parser.add_argument('--tkn_version', type=str, help='tkn version to be used for downstream tests')
parser.add_argument('--save_environment', action='store_true', help='Save environment after test is run')

args = parser.parse_args()

if args.test_type == 'downstream':
    if args.tkn_version is None:
        parser.error('--tkn_version is required if --test_type is downstream')
    else:
        os.environ['TKN_VERSION'] = args.tkn_version

if args.ocp_username is None:
    if 'OCP_USERNAME' not in os.environ:
        parser.error(
            'provide username for ocp as environment variable OCP_USERNAME or provide value for --ocp_username')
else:
    os.environ['OCP_USERNAME'] = args.ocp_username

if args.ocp_password is None:
    if 'OCP_PASSWORD' not in os.environ:
        parser.error(
            'provide password for ocp as environment variable OCP_PASSWORD or provide value for --ocp_password')
else:
    os.environ['OCP_PASSWORD'] = args.ocp_password

if args.ocp_server_address is None:
    if 'OCP_SERVER_ADDRESS' not in os.environ:
        parser.error(
            'provide server address for ocp as environment variable OCP_SERVER_ADDRESS or '
            'provide value for --ocp_server_address')
else:
    os.environ['OCP_SERVER_ADDRESS'] = args.ocp_server_address

os_type = args.operating_system
test_type = args.test_type
save_environment = args.save_environment
keypair_name = args.keypair_name
private_key_location = args.private_key_location
return_status = True
return_message = ''

# Set VM name and keypair name as environment variables
rand_string = ''.join(random.choices(string.ascii_lowercase +
                                     string.digits, k=6))
vm_name = 'test-tkn-{}-{}'.format(os_type, rand_string)

# Set image ID and flavor ID as environment variables
with open('flavor_image_config.json') as config_file:
    data = json.load(config_file)
    os.environ["IMAGE_ID"] = data[os_type]['image']
    os.environ["FLAVOR_ID"] = data[os_type]['flavor']
    os.environ['VM_NAME'] = vm_name
    os.environ['KEYPAIR_NAME'] = keypair_name
    os.environ['NETWORK'] = args.network

# Create VM
print(
    '============================== Creating {} VM with name {} ====================================='.format(os_type,
                                                                                                              vm_name),
    flush=True)
output = subprocess.run('ansible-playbook create-vm.yml -vvvv'.split(), stdout=subprocess.PIPE, text=True)

if output.returncode == 0:
    print('============================== sleeping for 2 minute =====================================')
    time.sleep(120)

    # Get VM details
    output = subprocess.run('openstack server show {} -f json'.format(vm_name).split(), stdout=subprocess.PIPE,
                            text=True)
    vm_info = json.loads(output.stdout)
    vm_id = vm_info['id']
    volume_attached = vm_info['volumes_attached']
    match = re.search(r'\d+\.\d+\.\d+\.\d+', vm_info['addresses'])
    vm_ip = match.group(0)

    # Build inventory file
    os_username = {'ubuntu16': 'ubuntu', 'rhel8': 'cloud-user', 'windows10': 'Admin', 'fedora31': 'fedora'}

    if os_type == 'windows10':
        output = subprocess.run('nova get-password {} {}'.format(vm_id, private_key_location).split(),
                                stdout=subprocess.PIPE, text=True)
        win_password = output.stdout

        inventory_content = '''
    [test-host]
    {}

    [test-host:vars]
    ansible_user={}
    ansible_password={}
    ansible_connection=winrm
    ansible_winrm_server_cert_validation=ignore
    '''.format(vm_ip, os_username[os_type], win_password)
    else:
        inventory_content = '''
    [test-host]
    {}

    [test-host:vars]
    ansible_user={}
    ansible_ssh_common_args='-o StrictHostKeyChecking=no'
    '''.format(vm_ip, os_username[os_type])
    with open('hosts', 'w') as f:
        f.write(inventory_content)

    playbook_name = 'linux' if os_type in ['rhel8', 'ubuntu16', 'fedora31'] else 'windows'

    # Install tkn on remote machine
    if test_type == 'downstream':
        print(
            '============================== Install tkn on VM {} ====================================='.format(vm_name),
            flush=True)
        output = subprocess.run(
            'ansible-playbook install-tkn-{}.yml -v -i hosts --private-key {}'.format(playbook_name,
                                                                                      private_key_location).split(),
            stdout=subprocess.PIPE, text=True)
        if output.returncode != 0:
            return_status = False
            return_message = output.stdout

    if output.returncode == 0:
        print('============================== running {} cli tests on {} ====================================='.format(
            test_type, vm_name), flush=True)
        output = subprocess.run(
            'ansible-playbook run-cli-{}-tests-{}.yml -i hosts --private-key {}'.format(test_type, playbook_name,
                                                                                        private_key_location).split(),
            stdout=subprocess.PIPE, text=True)
        if output.returncode == 0:
            if 'FAILED! =>' in output.stdout or '"msg": "non-zero return code"' in output.stdout:
                return_status = False
                return_message = 'Check the test execution logs'
            match = re.search(r'"output.stdout_lines": \[(.*)\]', output.stdout, re.DOTALL)
            if match:
                output = match.group(1)
                output = output.split('\n')
                for i in output:
                    i = i.strip()
                    i = i.strip(',')
                    i = i.strip('"')
                    if test_type == 'downstream':
                        print(codecs.getdecoder("unicode_escape")(i)[0])
                    else:
                        print(i)
            else:
                return_status = False
                return_message = output.stdout
        else:
            return_status = False
            return_message = output.stdout
    else:
        return_status = False
        return_message = output.stdout

    if save_environment:
        print('============================== VM {} saved for future use ====================================='.format(
            vm_name), flush=True)
    else:
        # Delete created VM
        print('============================== Deleting VM {} ====================================='.format(vm_name))
        subprocess.run('nova delete {}'.format(vm_id).split(), stdout=subprocess.PIPE, text=True)

        # Delete volume if present
        if volume_attached:
            time.sleep(90)
            print('============================== Deleting attached volume =====================================')
            volume_id = volume_attached.strip('id=')
            volume_id = volume_id.strip("'")
            output = subprocess.run('openstack volume delete {}'.format(volume_id).split(), stdout=subprocess.PIPE,
                                    text=True)
            print(output.stdout)
else:
    return_status = False
    return_message = output.stdout

if return_status is False:
    raise Exception('Script failed with error:\n{}'.format(return_message))
