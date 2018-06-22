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
# Author: Cognosys Technologies

###
### Warning! This script partitions and formats disk information be careful where you run it
###          This script is currently under development and has only been tested on Ubuntu images in Azure
###          This script is not currently idempotent and only works for provisioning at the moment

### Remaining work items
### -Alternate discovery options (Azure Storage)
### -Implement Idempotency and Configuration Change Support
### -Recovery Settings (These can be changed via API)

help()
{
    #TODO: Add help text here
    echo "This script installs kafka cluster on Ubuntu"
    echo "Parameters:"
    echo "-i Broker id"
    echo "-a Zookeeper IP addresses"
    echo "-t Kafka advertised host name; optional, for public accessing only"
    echo "-h Help"
}

log()
{
    # If you want to enable this logging add a un-comment the line below and add your account key
    #curl -X POST -H "content-type:text/plain" --data-binary "$(date) | ${HOSTNAME} | $1" https://logs-01.loggly.com/inputs/805ae6ae-6585-4f46-b8f8-978ae5433ea4/tag/http/
    echo "$1"
}

log "Begin execution of kafka script extension on ${HOSTNAME}"

if [ "${UID}" -ne 0 ];
then
    log "Script executed without root permissions"
    echo "You must be root to run this program." >&2
    exit 3
fi

# TEMP FIX - Re-evaluate and remove when possible
# This is an interim fix for hostname resolution in current VM
grep -q "${HOSTNAME}" /etc/hosts
if [ $? -eq $SUCCESS ];
then
  echo "${HOSTNAME}found in /etc/hosts"
else
  echo "${HOSTNAME} not found in /etc/hosts"
  # Append it to the hosts file if not there
  echo "127.0.0.1 $(hostname)" >> /etc/hosts
  log "Hostname ${HOSTNAME} added to /etc/hosts"
fi

#Script Parameters
BROKER_ID=0
ZOOKEEPER_IPS=""
ZOOKEEPER_PORT="2181"
KAFKADIR="/var/lib/kafkadir"
KAFKA_ADVERTISED=""

#Loop through options passed
while getopts :i:a:ta:h optname; do
    log "Option $optname set with value ${OPTARG}"
  case $optname in
    i)  #broker id
      BROKER_ID=${OPTARG}
      ;;
    a)  #zookeeper Private IP address prefix
      ZOOKEEPER_IPS=${OPTARG}
      ;;
    t) # kafka advertised host name
      KAFKA_ADVERTISED=${OPTARG}
      ;;
    h)  #show help
      help
      exit 2
      ;;
    \?) #unrecognized option - show help
      echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
      help
      exit 2
      ;;
  esac
done

# Install OpenJDK
install_java()
{
    log "Installing Java"
    apt-get -y update
    apt-get -y install openjdk-8-jre-headless
}

function join { local IFS="$1"; shift; echo "$*"; }

get_ip_port_list() {
    IFS=',' read -a HOST_IPS <<< "$1"

    declare -a EXPAND_STATICIP_RANGE_RESULTS=()

    for (( n=0; n<${HOST_IPS[1]}; n++ ))
    for ip in ${HOST_IPS[@]}
    do
        HOST="${ip}:${ZOOKEEPER_PORT}"
        EXPAND_STATICIP_RANGE_RESULTS+=($HOST)
    done

    echo "${EXPAND_STATICIP_RANGE_RESULTS[@]}"
}

# Install kafka
install_kafka()
{
    log "Installing Kafka"

    cd /usr/local
    min_ver=2.11
    maj_ver=0.9.0.0
    src_package="kafka_${min_ver}-${maj_ver}.tgz"
    download_url=http://archive.apache.org/dist/kafka/${maj_ver}/${src_package}

    rm -rf kafka
    mkdir -p kafka
    cd kafka

    if [[ ! -f "${src_package}" ]]; then
      log "Download Kafka from ${download_url}"
      wget ${download_url}
    fi
    tar zxf ${src_package}
    cd kafka_${min_ver}-${maj_ver}

    sed -r -i "s/(broker.id)=(.*)/\1=${BROKER_ID}/g" config/server.properties
    sed -r -i "s/(zookeeper.connect)=(.*)/\1=$(join , $(get_ip_port_list "${ZOOKEEPER_IPS}"))/g" config/server.properties
    sed -r -i "s/(log.dirs)=(.*)/\1=${KAFKADIR}/g" config/server.properties

    # Ensure new line before
    echo -e "\n" >> config/server.properties
    if [ ! -z "${KAFKA_ADVERTISED}" ]; then
      echo "advertised.host.name=${KAFKA_ADVERTISED}" >> config/server.properties
    else
      echo "advertised.host.name=$(hostname -I)" >> config/server.properties
    fi

    chmod u+x /usr/local/kafka/kafka_${min_ver}-${maj_ver}/bin/kafka-server-start.sh
    /usr/local/kafka/kafka_${min_ver}-${maj_ver}/bin/kafka-server-start.sh /usr/local/kafka/kafka_${min_ver}-${maj_ver}/config/server.properties &
}

# Primary Install Tasks
install_java
mkdir ${KAFKADIR}
install_kafka
