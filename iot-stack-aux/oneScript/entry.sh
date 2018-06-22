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

# Loop through options passed
while getopts :n:a:z:k:m:r:i:h optname; do
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
  for e;
  do
    [[ "$e" == "$match" ]] && return 0;
  done
  return 1
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

contain_index "${CUR_VM_INDEX}" "${ZK_VM_INDEXES[@]}"
if [ $? -eq 0 ]; then
    echo "install Zookeeper on ${VM_NAMES[${CUR_VM_INDEX}]}"
    zk_ips=$(get_ips "$(echo ${VM_IPS[@]})" "$(echo ${ZK_VM_INDEXES[@]})")
    echo "zk_ips := ${zk_ips}"
    /bin/bash ./zookeeper.sh -a "$(join , $(echo ${zk_ips[@]}))" -i "${CUR_VM_INDEX}"
    /bin/bash ./kafka.sh -a "$(join , $(echo ${zk_ips[@]}))" -i "${CUR_VM_INDEX}"
fi

contain_index "${CUR_VM_INDEX}" "${KAFKA_VM_INDEXES[@]}"
if [ $? -eq 0 ]; then
    echo "install Kafka on ${VM_NAMES[${CUR_VM_INDEX}]}"
fi

contain_index "${CUR_VM_INDEX}" "${MONGO_VM_INDEXES[@]}"
if [ $? -eq 0 ]; then
    echo "install MongoDB on ${VM_NAMES[${CUR_VM_INDEX}]}"
fi

contain_index "${CUR_VM_INDEX}" "${REDIS_VM_INDEXES[@]}"
if [ $? -eq 0 ]; then
    echo "install Redis on ${VM_NAMES[${CUR_VM_INDEX}]}"
fi