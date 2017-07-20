Use the following command to run the check_miners.yml playbook

ansible-playbook ./check_miners.yml -i w-inventory.yml

ansible-playbook -i w-inventory.yml -K claymore_nanopool.yml
