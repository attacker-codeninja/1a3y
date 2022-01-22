#!/bin/bash

# Mode octets finder

RESOLVERS=resolvers/mini_resolvers.txt

#######################################
# Find mode under list of IPs.
# Globals:
#   RESOLVERS
# Arguments:
#   IP list
# Outputs:
#   Writes CIDR to stdout
#######################################
modefinder(){
  if [[ -s "$1" ]]; then
    echo
    echo "[$(date +%H:%M:%S)] [math Mode] finding math Mode of the IP numbers"
    MODEOCTET=$(cut -f1 -d '.' $1 | sort -n | uniq -c | sort | tail -n1 | xargs)
    ISMODEOCTET1=$(echo $MODEOCTET | awk '{ print $1 }')
    if ((ISMODEOCTET1 > 1)); then
      MODEOCTET1=$(echo $MODEOCTET | awk '{ print $2 }')

      MODEOCTET=$(grep "^${MODEOCTET1}" $1 | cut -f2 -d '.' | sort -n | uniq -c | sort | tail -n1 | xargs)
      ISMODEOCTET2=$(echo $MODEOCTET | awk '{ print $1 }')
      if ((ISMODEOCTET2 > 1)); then
        MODEOCTET2=$(echo $MODEOCTET | awk '{ print $2 }')
        CIDR1="${MODEOCTET1}.${MODEOCTET2}.0.0/16"
        echo "[math Mode] found: $CIDR1"
        echo "[math Mode] resolve PTR of the IP numbers"
        # look at https://github.com/projectdiscovery/dnsx/issues/34 to add `-wd` support here
        mapcidr -silent -cidr $CIDR1 | dnsx -silent -resp-only -ptr -r $RESOLVERS | sort -u
      fi
    fi
    echo "[$(date +%H:%M:%S)] [math Mode] done."
  else
    echo "File $1 not found."
    exit 1
  fi
}

usage(){
  PROGNAME=$(basename $0)
  echo "Usage: ./modefinder.sh <realpath_list_of_ip>"
}

if [ $# -eq 0 ]; then
    echo "Error: expected positional arguments"
    usage
    exit 1
else

modefinder $1