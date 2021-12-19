#!/bin/bash -x

# Script works in current directory

scp_provision_script(){
    # download and wordlist dependencies to the fleet
    if axiom-scp '/root/.config/subfinder/config.yaml' 'lazy*':'/home/op/.config/subfinder/config.yaml'; then
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
    notification
}

main
exit 0
