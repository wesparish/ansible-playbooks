Use the following command to run the playbook

# Only need -K -k if this is the first time running Ansible on a target host
ansible-playbook -i test-inventory.yml -K -k site.yml
