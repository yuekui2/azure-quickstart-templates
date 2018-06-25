#!/bin/bash

help()
{
    echo "This script installs Kafka, Redis and Zookeeper cluster on Ubuntu"
    echo "Parameters (comma-delimited for array):"
    echo "-n VM names"
    echo "-a VM IP addresses"
    echo "-z Zookeeper VM indexes"
    echo "-k Kafka VM indexes"
    echo "-m MongoDB VM indexes"
    echo "-r Redis VM indexes"
    echo "-i Current VM index"
    echo "-t Replica set name"
    echo "-y Replica set key"
    echo "-u System administrator's user name"
    echo "-p System administrator's password"
    echo "-h Help"
}

log()
{
    # Uncomment to set logging service endpoint such as Loggly
    #curl -X POST -H "content-type:text/plain" --data-binary "$(date) | ${HOSTNAME} | $1" https://logs-01.loggly.com/inputs/805ae6ae-6585-4f46-b8f8-978ae5433ea4/tag/http/
    echo "$1"
}

if [ "${UID}" -ne 0 ]; then
    MSG="You must be root to run this program"
    log "Err: ${MSG}"
    echo "Err: ${MSG}" >&2
    exit 3
fi

declare -a VM_NAMES
declare -a VM_IPS
declare -a ZK_VM_INDEXES
declare -a KAFKA_VM_INDEXES
declare -a MONGO_VM_INDEXES
declare -a REDIS_VM_INDEXES
declare -i CUR_VM_INDEX

REPLICA_SET_NAME=""
REPLICA_SET_KEY=""
USERNAME=""
PWD=""

# Loop through options passed
while getopts :n:a:z:k:m:r:i:t:y:u:p:h optname; do
    log "Option $optname set with value ${OPTARG}"
  case $optname in
    n) # VM names
      IFS=',' read -ra VM_NAMES <<< ${OPTARG}
      ;;
    a) # VM IP addresses
      IFS=',' read -ra VM_IPS <<< ${OPTARG}
      ;;
    z) # Zookeeper VM indexes
      IFS=',' read -ra ZK_VM_INDEXES <<< ${OPTARG}
      ;;
    k) # Kafka VM indexes
      IFS=',' read -ra KAFKA_VM_INDEXES <<< ${OPTARG}
      ;;
    m) # MongoDB VM indexes
      IFS=',' read -ra MONGO_VM_INDEXES <<< ${OPTARG}
      ;;
    r) # Redis VM indexes
      IFS=',' read -ra REDIS_VM_INDEXES <<< ${OPTARG}
      ;;
    i) # Current VM index
      CUR_VM_INDEX=${OPTARG}
      ;;
    t) # Replica set name
      REPLICA_SET_NAME=${OPTARG}
      ;;
    y) # Replica set key
      REPLICA_SET_KEY=${OPTARG}
      ;;
    u) # User name
      USERNAME=${OPTARG}
      ;;
    p) # Password
      PWD=${OPTARG}
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

contain_index () {
  local e match="$1"
  shift
  count=-1
  for e;
  do
    count=$((count+1))
    [[ "$e" == "$match" ]] && return $count;
  done
  return -1
}

function join { local IFS="$1"; shift; echo "$*"; }

get_ips() {
    IFS=' ' read -ra ips <<< $1
    IFS=' ' read -ra indexes <<< $2

    declare -a IPS_MATCHED=()

    for i in ${indexes[@]}
    do
        IPS_MATCHED+=( ${ips[$i]} )
    done

    echo "${IPS_MATCHED[@]}"
}

validate_input() {
    vm_count=${#VM_NAMES[@]}
    ip_count=${#VM_IPS[@]}

    if [ ${vm_count} -ne ${ip_count} ]; then
        echo "VM count (${vm_count}) should be equal to IP count (${ip_count})"
        exit 1
    fi

    if [ ${vm_count} -lt 1 ]; then
        echo "VM count should be at least 1"
        exit 1
    fi

    if [[ ! ${CUR_VM_INDEX} -lt ${vm_count} ]] || [ ${CUR_VM_INDEX} -lt 0 ]; then
        echo "VM index ${CUR_VM_INDEX} is NOT valid [0, ${vm_count})"
        exit 1
    fi

    for i in ${ZK_VM_INDEXES[@]}
    do
        if [[ ! ${i} -lt ${vm_count} ]] || [ ${i} -lt 0 ]; then
            echo "Zookeeper VM index ${i} is NOT valid [0, ${vm_count})"
            exit 1
        fi
    done

    for i in ${KAFKA_VM_INDEXES[@]}
    do
        if [[ ! ${i} -lt ${vm_count} ]] || [ ${i} -lt 0 ]; then
            echo "Kafka VM index ${i} is NOT valid [0, ${vm_count})"
            exit 1
        fi
    done

    for i in ${MONGO_VM_INDEXES[@]}
    do
        if [[ ! ${i} -lt ${vm_count} ]] || [ ${i} -lt 0 ]; then
            echo "MongoDB VM index ${i} is NOT valid [0, ${vm_count})"
            exit 1
        fi
    done

    for i in ${REDIS_VM_INDEXES[@]}
    do
        if [[ ! ${i} -lt ${vm_count} ]] || [ ${i} -lt 0 ]; then
            echo "Redis VM index ${i} is NOT valid [0, ${vm_count})"
            exit 1
        fi
    done

    # Replica set key must have length between 6 and 1024 chars
    if [ ${#REPLICA_SET_KEY} -lt 6 ] || [ ${#REPLICA_SET_KEY} -gt 1024 ]; then
        echo "Replica set key has length ${#REPLICA_SET_KEY}, must be between 6 and 1024 chars"
        exit 1
    fi
}

validate_input

contain_index "${CUR_VM_INDEX}" "${ZK_VM_INDEXES[@]}"
INSTANCE_INDEX=$?
if [ ${INSTANCE_INDEX} -ne 255 ]; then
    echo "install Zookeeper on ${VM_NAMES[${CUR_VM_INDEX}]}"
    zk_ips=$(get_ips "$(echo ${VM_IPS[@]})" "$(echo ${ZK_VM_INDEXES[@]})")
    echo "zk_ips := ${zk_ips}"
    /bin/bash ./zookeeper.sh -a "$(join , $(echo ${zk_ips[@]}))" -i "${INSTANCE_INDEX}"
fi

contain_index "${CUR_VM_INDEX}" "${KAFKA_VM_INDEXES[@]}"
INSTANCE_INDEX=$?
if [ ${INSTANCE_INDEX} -ne 255 ]; then
    echo "install Kafka on ${VM_NAMES[${CUR_VM_INDEX}]}"
    zk_ips=$(get_ips "$(echo ${VM_IPS[@]})" "$(echo ${ZK_VM_INDEXES[@]})")
    echo "zk_ips := ${zk_ips}"
    /bin/bash ./kafka.sh -a "$(join , $(echo ${zk_ips[@]}))" -i "${INSTANCE_INDEX}"
fi

contain_index "${CUR_VM_INDEX}" "${MONGO_VM_INDEXES[@]}"
INSTANCE_INDEX=$?
if [ ${INSTANCE_INDEX} -ne 255 ]; then
    echo "install MongoDB on ${VM_NAMES[${CUR_VM_INDEX}]}"
    mongo_ips=$(get_ips "$(echo ${VM_IPS[@]})" "$(echo ${MONGO_VM_INDEXES[@]})")
    echo "mongo_ips := ${mongo_ips}"
    /bin/bash ./mongodb-ubuntu-install.sh -a "$(join , $(echo ${mongo_ips[@]}))" -i "${INSTANCE_INDEX}" -r ${REPLICA_SET_NAME} -k ${REPLICA_SET_KEY} -u ${USERNAME} -p ${PWD}
fi

contain_index "${CUR_VM_INDEX}" "${REDIS_VM_INDEXES[@]}"
INSTANCE_INDEX=$?
if [ ${INSTANCE_INDEX} -ne 255 ]; then
    echo "install Redis on ${VM_NAMES[${CUR_VM_INDEX}]}"
    redis_ips=$(get_ips "$(echo ${VM_IPS[@]})" "$(echo ${REDIS_VM_INDEXES[@]})")
    echo "redis_ips := ${redis_ips}"
    /bin/bash ./redis-sentinel.sh -a "$(join , $(echo ${redis_ips[@]}))" -i "${INSTANCE_INDEX}"
fi