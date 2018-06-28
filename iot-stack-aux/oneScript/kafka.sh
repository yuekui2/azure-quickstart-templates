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
#
# Based on https://github.com/Azure/azure-quickstart-templates/tree/master/kafka-ubuntu-multidisks

###
### This script has been refactored to be idempotent.

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
    echo "-p Kafka default number of partitions"
    echo "-h Help"
}

log()
{
    # Uncomment to set logging service endpoint such as Loggly
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
KAFKA_DIR="/var/lib/kafkadir"
KAFKA_ADVERTISED=""

KAFKA_MIN_VER=2.12
KAFKA_MAJ_VER=0.11.0.2
KAFKA_PARTITIONS=16

#Loop through options passed
while getopts :i:a:t:p:h optname; do
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
    p) # kafka default number of partitions
      KAFKA_PARTITIONS=${OPTARG}
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

    for ip in ${HOST_IPS[@]}
    do
        HOST="${ip}:${ZOOKEEPER_PORT}"
        EXPAND_STATICIP_RANGE_RESULTS+=($HOST)
    done

    echo "${EXPAND_STATICIP_RANGE_RESULTS[@]}"
}

stop_kafka()
{
	# Find out what PID the Kafka instance is running as (if any)
	KAFKAPID=`ps -ef | grep '/usr/local/kafka/' | grep -v grep | awk '{print $2}'`

	if [ ! -z "$KAFKAPID" ]; then
		log "Stopping Kafka daemon processes (PID $KAFKAPID)"

		kill -15 $KAFKAPID
	fi

	sleep 5s
}

# Install kafka
install_kafka()
{
    log "Installing Kafka"

    cd /usr/local
    src_package="kafka_${KAFKA_MIN_VER}-${KAFKA_MAJ_VER}.tgz"
    download_url=http://archive.apache.org/dist/kafka/${KAFKA_MAJ_VER}/${src_package}

    stop_kafka

    rm -rf kafka
    mkdir -p kafka
    cd kafka

    if [[ ! -f "${src_package}" ]]; then
      log "Download Kafka from ${download_url}"
      wget ${download_url}
    fi
    tar zxf ${src_package}
    cd kafka_${KAFKA_MIN_VER}-${KAFKA_MAJ_VER}

    sed -r -i "s/(broker.id)=(.*)/\1=${BROKER_ID}/g" config/server.properties
    sed -r -i "s/(zookeeper.connect)=(.*)/\1=$(join , $(get_ip_port_list "${ZOOKEEPER_IPS}"))/g" config/server.properties
    sed -r -i "s/(log.dirs)=(.*)/\1=${KAFKA_DIR}/g" config/server.properties
    sed -r -i "s/(num.partitions)=(.*)/\1=${KAFKA_PARTITIONS}/g" config/server.properties

    # Ensure new line before
    echo -e "\n" >> config/server.properties
    if [ ! -z "${KAFKA_ADVERTISED}" ]; then
      echo "advertised.host.name=${KAFKA_ADVERTISED}" >> config/server.properties
    else
      echo "advertised.host.name=$(hostname -I)" >> config/server.properties
    fi

    chmod u+x /usr/local/kafka/kafka_${KAFKA_MIN_VER}-${KAFKA_MAJ_VER}/bin/kafka-server-start.sh
    # Avoid exception of  Failed to acquire lock on file .lock in /tmp/kafka-logs during Kafka starts.
    rm /tmp/kafka-logs/.lock
    /usr/local/kafka/kafka_${KAFKA_MIN_VER}-${KAFKA_MAJ_VER}/bin/kafka-server-start.sh /usr/local/kafka/kafka_${KAFKA_MIN_VER}-${KAFKA_MAJ_VER}/config/server.properties &
}

# Primary Install Tasks
install_java
mkdir ${KAFKA_DIR}
install_kafka
