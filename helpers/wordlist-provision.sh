#!/bin/bash -x

# Special crafted for axiom's fleet droplets
# Script works in current directory /home/op/

third_party_wordlists(){
    # DNS brute-force
    if ! wget -nc https://wordlists-cdn.assetnote.io/data/manual/best-dns-wordlist.txt; then
        exit 1
    fi
    if ! wget -nc -O six2dez-dns-wordlist.txt https://gist.githubusercontent.com/six2dez/a307a04a222fab5a57466c51e1569acf/raw/subdomains.txt; then
        exit 1
    fi
    # LFI payload
    if ! wget -nc https://raw.githubusercontent.com/storenth/LFI-Payload-List/master/lfi-payload.txt; then
        exit 1
    fi
    # API endpoint brute-force
    if ! wget -nc https://raw.githubusercontent.com/storenth/bruteforce-lists/master/api.txt; then
        exit 1
    fi
}

notification(){
    echo
    echo "Wordlist copied to axiom-fleet"
}

main() {
    # Entry point
    third_party_wordlists
    notification
}

main
exit 0
