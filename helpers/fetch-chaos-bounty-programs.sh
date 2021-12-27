#!/bin/bash
# get all paid bug bounty programs target list
# 

# https://youtu.be/z_Bp_SUdaIo?t=624


NUMBEROFPROGRAMS="$@"
curl -s https://raw.githubusercontent.com/projectdiscovery/public-bugbounty-programs/master/chaos-bugbounty-list.json | jq -r ".programs[] | select(.bounty==true) .domains[]" | head -n "${NUMBEROFPROGRAMS}"
