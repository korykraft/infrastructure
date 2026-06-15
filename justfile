default_inventory := "ansible/inventory-vm.ini"

play inventory=default_inventory:
    ansible-playbook -i {{inventory}} ansible/site.yml -K --ask-vault-pass
