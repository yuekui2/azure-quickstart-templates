#!/bin/bash

help()
{
    echo "This script does the Unbuntu jumpbox setup"
}

if [ "${UID}" -ne 0 ];
then
    echo "You must be root to run this program." >&2
    exit 3
fi

# install python to test redis
apt-get -y update
apt-get -y install python-pip
#pip install virtualenv
#/usr/bin/easy_install virtualenv
pip install redis
