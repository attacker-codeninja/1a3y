#!/bin/bash

# Mode octets finder

RESOLVERS=resolvers/mini_resolvers.txt

#######################################
# Find mode under list of IPs.
# Globals:
#   RESOLVERS
# Arguments:
#   IP list
#   Mode: 16/24, means subnet mask
# Outputs:
#   Writes PTR records to stdout
#######################################
modefinder(){
  if [[ -s "$1" ]]; then
    echo
    echo "[$(date +%H:%M:%S)] [math Mode] finding math Mode of the IP numbers"
    if [[ -n "$2" ]]; then
      if (($2 == 16)); then
        MODEOCTET=$(cut -f1 -d '.' $1 | sort -n | uniq -c | sort | tail -n1 | xargs)
        ISMODEOCTET1=$(echo $MODEOCTET | cut -f1 -d ' ')
        if ((ISMODEOCTET1 > 1)); then
          MODEOCTET1=$(echo $MODEOCTET | cut -f2 -d ' ')

          MODEOCTET=$(grep "^${MODEOCTET1}" $1 | cut -f2 -d '.' | sort -n | uniq -c | sort | tail -n1 | xargs)
          ISMODEOCTET2=$(echo $MODEOCTET | cut -f1 -d ' ')
          if ((ISMODEOCTET2 > 1)); then
            MODEOCTET2=$(echo $MODEOCTET | cut -f2 -d ' ')
            CIDR1="${MODEOCTET1}.${MODEOCTET2}.0.0/16"
            echo "[math Mode /16] found: $CIDR1"
            echo "[math Mode /16] resolve PTR of the IP numbers"
            # look at https://github.com/projectdiscovery/dnsx/issues/34 to add `-wd` support here
            mapcidr -silent -cidr $CIDR1 | dnsx -silent -resp-only -ptr -r $RESOLVERS | sort -u
          fi
        fi

      elif (($2 == 24)); then
        MODEOCTET=$(cut -f1 -d '.' $1 | sort -n | uniq -c | sort | tail -n1 | xargs)
        ISMODEOCTET1=$(echo $MODEOCTET | cut -f1 -d ' ')

        if ((ISMODEOCTET1 > 1)); then
          MODEOCTET1=$(echo $MODEOCTET | cut -f2 -d ' ')
          MODEOCTET=$(grep "^${MODEOCTET1}" $1 | cut -f2 -d '.' | sort -n | uniq -c | sort | tail -n1 | xargs)
          ISMODEOCTET2=$(echo $MODEOCTET | cut -f1 -d ' ')

          if ((ISMODEOCTET2 > 1)); then
            MODEOCTET2=$(echo $MODEOCTET | cut -f2 -d ' ')
            MODEOCTET=$(grep "^${MODEOCTET1}.${MODEOCTET2}" $1 | cut -f3 -d '.' | sort -n | uniq -c | sort | tail -n1 | xargs)
            ISMODEOCTET3=$(echo $MODEOCTET | cut -f1 -d ' ')

            if ((ISMODEOCTET3 > 1)); then
              MODEOCTET3=$(echo $MODEOCTET | cut -f2 -d ' ')

              CIDR1="${MODEOCTET1}.${MODEOCTET2}.${MODEOCTET3}.0/24"
              echo "[math Mode /24] found: $CIDR1"
              echo "[math Mode /24] resolve PTR of the IP numbers"
              # look at https://github.com/projectdiscovery/dnsx/issues/34 to add `-wd` support here
              mapcidr -silent -cidr $CIDR1 | dnsx -silent -resp-only -ptr -r $RESOLVERS | sort -u

            fi
          fi
        fi
      else
        echo "Mode argument error: 16/24 only supports"
        usage
        exit 1
      fi
    else
      usage
      exit 1
    fi
    echo "[$(date +%H:%M:%S)] [math Mode] done."
  else
    echo "File $1 not found."
    exit 1
  fi
}

usage(){
  PROGNAME=$(basename $0)
  echo "Usage: ./modefinder.sh <realpath_list_of_ip> <mode>"
  echo "example: ./modefinder.sh dnsprobe_ip.txt 24"
}

if [ "$#" -eq 0 ]; then
    echo "Error: expected positional arguments"
    usage
    exit 1
fi

modefinder "$@"
