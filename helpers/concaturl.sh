#!/bin/bash

# Concatenate list of potential dns with each line of the list of urls


usage(){
  PROGNAME=$(basename $0)
  echo "Usage: ./concaturl.sh <lis-of-url> <list-of-dns-brute-words>"
  echo "example: ./concaturl.sh live-subs.txt six2dez-dns-wordlist.txt"
}

if [ "$#" -eq 0 ]; then
    echo "Error: expected positional arguments"
    usage
    exit 1
fi

#######################################
# COncat each line of one list with each line of another.
# Arguments:
#   list of live servers
#   wordlist of potential subs
# Outputs:
#   Writes concatenated lines to stdout
#######################################
concaturl(){
  while read domainline; do
    while read dnsline; do
      echo "${dnsline}.${domainline}"
    done < "$2"
  done < "$1"
}

concaturl "$@"
