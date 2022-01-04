#!/bin/bash -x

apt -y update && apt upgrade
apt -y install less wordlists dirb man
