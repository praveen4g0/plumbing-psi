This folder contains the ansible playbooks to create VMs and run the upstream/downstream cli tests on RHEL 8, Fedora 31, Ubuntu 16.04 and Windows10.
The `run-playbooks.py` helps to run the anible playbooks.


Prerequisites
-------------
1. PSI account - access is managed by Rover group [psi-pipelines-users](https://rover.redhat.com/groups/group/psi-pipelines-users). Ask group owner for access.
2. [OpenStack CLI](https://pypi.org/project/python-openstackclient/) - this repo already contains `clouds.yaml` file, you need to change username in it and create `~/.config/openstack/secure.yaml` containing your Kerberos password.
3. Ansible installed `pip install ansible`


Example for usage of run-playbooks.py
-------------
* Run `python run-playbooks.py --help` to get the help
```
$ python run-playbooks.py --help
usage: run-playbooks.py [-h] --operating_system {windows10,rhel8,fedora31,ubuntu16} --network NETWORK --keypair_name KEYPAIR_NAME --private_key_location PRIVATE_KEY_LOCATION --test_type {upstream,downstream}
                        [--ocp_username OCP_USERNAME] [--ocp_password OCP_PASSWORD] [--ocp_server_address OCP_SERVER_ADDRESS] [--tkn_version TKN_VERSION] [--save_environment]

optional arguments:
  -h, --help            show this help message and exit
  --operating_system {windows10,rhel8,fedora31,ubuntu16}
                        Operating system you want to create and run tests
  --network NETWORK     Name or ID of a network to attach this instance to
  --keypair_name KEYPAIR_NAME
                        Keypair name to create VM
  --private_key_location PRIVATE_KEY_LOCATION
                        private key location
  --test_type {upstream,downstream}
                        Type of test you want to run
  --ocp_username OCP_USERNAME
                        OCP cluster username or set environment variable OCP_USERNAME
  --ocp_password OCP_PASSWORD
                        OCP cluster password or set environment variable OCP_PASSWORD
  --ocp_server_address OCP_SERVER_ADDRESS
                        OCP cluster server address or set environment variable OCP_SERVER_ADDRESS
  --tkn_version TKN_VERSION
                        tkn version to be used for downstream tests
  --save_environment    Save environment after test is run

```

* Run upstream tests on ubuntu16
```
$ python run-playbooks.py --operating_system ubuntu16 --test_type upstream --ocp_username <ocp-username> --ocp_password <ocp-password> --ocp_server_address <ocp-server-address> --network <network-name> --keypair_name <keypair-name> --private_key_location <private-key-location> 
```
* Run downstream tests on fedora31 and save environment
```
$ python run-playbooks.py --operating_system fedora31 --test_type upstream --ocp_username <ocp-username> --ocp_password <ocp-password> --ocp_server_address <ocp-server-address> --network <network-name> --keypair_name <keypair-name> --private_key_location <private-key-location> --tkn_version 0.9.0
```

Note
----------
When you save the environment using `--save-environment`, make sure that you delete the keypair and volume once after deleting the VM