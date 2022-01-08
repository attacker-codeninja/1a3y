#!/bin/bash
# get all paid bug bounty programs target list
# 

# https://raw.githubusercontent.com/arkadiyt/bounty-targets-data/master/data/hackerone_data.json


NUMBEROFPROGRAMS="$@"
curl -s https://raw.githubusercontent.com/arkadiyt/bounty-targets-data/master/data/hackerone_data.json | jq -r ".[] | select(.offers_bounties==true) .targets .in_scope[]"
