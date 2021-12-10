#!/bin/bash -x

# Script works in current directory

scp_provision_script(){
    # download and wordlist dependencies to the fleet
    if axiom-scp '/root/1a3y/helpers/wordlist-provision.sh' 'lazy*':'/home/op/'; then
        axiom-exec 'chmod +x /home/op/lists/wordlist-provision.sh'
        axiom-exec '/home/op/lists/wordlist-provision.sh'
        axiom-exec 'sudo ln -s /usr/bin/python3 /usr/bin/python'
    else
        exit 1
    fi
}

notification(){
    echo
    echo "axiom's fleet is ready to launch the 1a3y"
}

main() {
    # Entry point
    scp_provision_script
    1a3y_custom_helpers
    notification
}

main
exit 0
