#!/bin/bash

help()
{
    echo "This script does the Unbuntu VM setup"
}

if [ "${UID}" -ne 0 ];
then
    echo "You must be root to run this program." >&2
    exit 3
fi

#Format the data disk
bash vm-disk-utils-0.1.sh
