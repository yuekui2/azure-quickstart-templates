#!/bin/bash

# The MIT License (MIT)
#
# Copyright (c) 2015 Microsoft Azure
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Based on https://github.com/Azure/azure-quickstart-templates/tree/master/kafka-ubuntu-multidisks

###
### This script has been refactored to be idempotent.

### Remaining work items
### -Alternate discovery options (Azure Storage)
### -Implement Configuration Change Support
### -Recovery Settings (These can be changed via API)

help()
{
    echo "This script installs Zookeeper cluster on Ubuntu"
    echo "Parameters:"
    echo "-a Zookeeper IP addresses (comma-delimited)"
    echo "-i Current VM index"
    echo "-h Help"
}

log()
{
    # Uncomment to set logging service endpoint such as Loggly
    #curl -X POST -H "content-type:text/plain" --data-binary "$(date) | ${HOSTNAME} | $1" https://logs-01.loggly.com/inputs/805ae6ae-6585-4f46-b8f8-978ae5433ea4/tag/http/
    echo "$1"
}

if [ "${UID}" -ne 0 ]; then
    local MSG = "You must be root to run this program"
    log "Err: ${MSG}"
    echo "Err: ${MSG}" >&2
    exit 3
fi

# Script Parameters
ZK_MYID=0
ZK_IPS=""

# Loop through options passed
while getopts :i:a:h optname; do
    log "Option $optname set with value ${OPTARG}"
  case $optname in
    i) # zookeeper myid using VM index
      ZK_MYID=$((${OPTARG}+1))
      ;;
    a) # zookeeper IP addresses
      ZK_IPS=${OPTARG}
      ;;
    h) # show help
      help
      exit 2
      ;;
    \?) # unrecognized option
      echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
      help
      exit 2
      ;;
  esac
done

# Install Java OpenJDK and Zookeeper
install_java_zk()
{
    log "Stopping Zookeeper if existing"
    service zookeeper stop

    log "Removing Zookeeper if existing"
    apt-get -y purge zookeeperd
    apt-get -y autoremove

    log "Installing OpenJDK and Zookeeper"
    apt-get -y update
    apt-get -y install openjdk-8-jre-headless
    apt-get -y install zookeeperd
}

setup_zookeeper()
{
    echo ${ZK_MYID} > /var/lib/zookeeper/myid

    # Split IP addresses and write to config in the following format:
    # server.1=10.0.1.10:2888:3888
    # server.2=10.0.1.11:2888:3888
    # server.3=10.0.1.12:2888:3888
    IFS=',' read -a HOST_IPS <<< ${ZK_IPS}
    for (( n=0; n<${#HOST_IPS[@]}; n++))
    do
        echo "server.$(expr ${n} + 1)=${HOST_IPS[${n}]}:2888:3888" >> /etc/zookeeper/conf/zoo.cfg
    done

    service zookeeper restart
}

# Main scripts
log "Begin execution of Zookeeper script extension on ${HOSTNAME}"

# Hostname resolution
grep -q "${HOSTNAME}" /etc/hosts
if [ $? -ne 0 ]; then
    echo "127.0.0.1 ${HOSTNAME}" >> /etc/hosts
    log "Hostname ${HOSTNAME} added to /etc/hosts"
fi

install_java_zk
setup_zookeeper