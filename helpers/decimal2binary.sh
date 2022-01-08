#!/bin/bash

# formatted to 8-bit output
perl -e 'printf "%08b\n",'"$1"

# opposite operation
# perl -le 'print 0b11111111'
