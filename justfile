default_inventory := "ansible/inventory.ini"

# Run the playbook. Extra args pass through, e.g. `just play --tags stacks`.
play *args:
    ansible-playbook -i {{default_inventory}} ansible/site.yml -K --ask-vault-pass {{args}}

# Snapshot the Kan database now (run on the VM).
kan-backup:
    ./scripts/kan-backup.sh

# Back up all service data now (run on the VM).
backup:
    ./scripts/backup.sh
