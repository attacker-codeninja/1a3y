#!/bin/bash
#
# Perform simplest fuzzing

#######################################
# send /dev/random data to the port
# Arguments:
#   naabu out
# Outputs:
#   Writes to stdout
#######################################
fuzz(){
  while read line; do
    IP=$(echo $line | cut -f1 -d ':')
    PORT=$(echo $line | cut -f2 -d ':')
    echo "[cat /dev/random] fuzzing $IP using $PORT port"

    cat /dev/random |  nc -zv $IP $PORT
    echo
  done < $1
}

fuzz $1
