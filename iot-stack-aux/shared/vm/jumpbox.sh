#!/bin/bash

help()
{
    echo "This script does the Unbuntu jumpbox setup"
}

if [ "${UID}" -ne 0 ];
then
    log "Script executed without root permissions"
    echo "You must be root to run this program." >&2
    exit 3
fi

# install python to test redis
apt-get -y update
apt-get -y install python-pip
pip install virtualenv
/usr/bin/easy_install virtualenv
pip install redis

# virtualenv --python=/usr/bin/python3 venvs/redistest
# source ~/venvs/redistest/bin/activate