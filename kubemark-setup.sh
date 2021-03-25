#!/bin/bash
# Credit: this script is based on https://github.com/sonyafenge/arktos-tool/blob/master/perftools/Howtorunperf-tests-scaleout.md
# this script is supposed to be sourced.
# todo: add multi TP/multi RP

[[ -z $1 ]] && echo "MUST specify RUN_PREFIX in format like etcd343-0312-1x500" && return 1
[[ -z $2 ]] && echo "MUST specify KUBEMARK_NUM_NODES in one of supported values 1, 2, 100, 500, 10000" && return 2

export RUN_PREFIX=$1
export KUBEMARK_NUM_NODES=$2

function calc_gce_resource_params() {
  local size=${1}
  case "$size" in
  1)
  export MASTER_DISK_SIZE=100GB 
  export MASTER_ROOT_DISK_SIZE=100GB
  export MASTER_SIZE=n1-standard-4
  export NODE_SIZE=n1-standard-4
  export NODE_DISK_SIZE=100GB
  ;;
  2)
  export MASTER_DISK_SIZE=200GB 
  export MASTER_ROOT_DISK_SIZE=200GB
  export MASTER_SIZE=n1-standard-4
  export NODE_SIZE=n1-standard-4
  export NODE_DISK_SIZE=200GB
  ;;
  100)
  export MASTER_DISK_SIZE=200GB 
  export MASTER_ROOT_DISK_SIZE=200GB
  export MASTER_SIZE=n1-highmem-16
  export NODE_SIZE=n1-highmem-16
  export NODE_DISK_SIZE=200GB
  ;;
  500)
  export MASTER_DISK_SIZE=200GB 
  export MASTER_ROOT_DISK_SIZE=200GB
  export MASTER_SIZE=n1-highmem-32
  export NODE_SIZE=n1-highmem-16
  export NODE_DISK_SIZE=200GB
  ;;
  10000)
  export MASTER_DISK_SIZE=1000GB 
  export MASTER_ROOT_DISK_SIZE=1000GB
  export MASTER_SIZE=n1-highmem-96
  export NODE_SIZE=n1-highmem-16
  export NODE_DISK_SIZE=200GB    ## seems wastful if asking for 1GB disk for node"
  ;;
  *)
  echo "invalid KUBEMARK_NUM_NODES."
  return -1
  ;;
  esac
}
calc_gce_resource_params ${KUBEMARK_NUM_NODES} || (echo "MUST specify KUBEMARK_NUM_NODES in one of supported values 1, 2, 100, 500, 10000"; return 3)

# https://github.com/fabric8io/kansible/blob/master/vendor/k8s.io/kubernetes/docs/devel/kubemark-guide.md
# ~17.5 hollow-node pods per cpu core ==> 16 cores: 110 hollow-nodes
declare -x -i NUM_NODES=("${KUBEMARK_NUM_NODES}" + 110 -1)/110
echo "${NUM_NODES} admin minion nodes"
# export NUM_NODES="${NUM_NODES}"

export SCALEOUT_CLUSTER=true
export USE_INSECURE_SCALEOUT_CLUSTER_MODE=true		## insecure mode
export SCALEOUT_TP_COUNT=1				## TP number
export SCALEOUT_RP_COUNT=1				## RP number
export KUBE_GCE_ZONE=${KUBE_GCE_ZONE-us-central1-b}
export KUBE_GCE_ENABLE_IP_ALIASES=true
export KUBE_GCE_PRIVATE_CLUSTER=true
export KUBE_GCE_INSTANCE_PREFIX=${RUN_PREFIX}
export KUBE_GCE_NETWORK=${RUN_PREFIX}
export CREATE_CUSTOM_NETWORK=true
export ENABLE_KCM_LEADER_ELECT=false
export ENABLE_SCHEDULER_LEADER_ELECT=false
export ETCD_QUOTA_BACKEND_BYTES=8589934592
export SHARE_PARTITIONSERVER=false
export LOGROTATE_FILES_MAX_COUNT=50
export LOGROTATE_MAX_SIZE=200M
export KUBE_ENABLE_APISERVER_INSECURE_PORT=true
export KUBE_ENABLE_PROMETHEUS_DEBUG=true
export KUBE_ENABLE_PPROF_DEBUG=true
export TEST_CLUSTER_LOG_LEVEL=--v=2
export HOLLOW_KUBELET_TEST_LOG_LEVEL=--v=2
export GOPATH=$HOME/go

export SHARED_CA_DIRECTORY=/tmp/${USER}/ca
mkdir -p ${SHARED_CA_DIRECTORY}

date
echo "starting admin cluster ..."
./cluster/kube-up.sh
echo "starting kubemark clusters ..."
./test/kubemark/start-kubemark.sh

# optional: sanity check

# start perf tool
export SCALEOUT_TEST_TENANT=arktos
# create the test tenant in kubemark TP cluster
./_output/dockerized/bin/linux/amd64/kubectl --kubeconfig=./test/kubemark/resources/kubeconfig.kubemark-proxy create tenant ${SCALEOUT_TEST_TENANT}

export RUN_NAME=${RUN_PREFIX}
export TENANT_PERF_LOG_DIR=~/logs/perf-test/gce-${KUBEMARK_NUM_NODES}/arktos/${RUN_NAME}/${SCALEOUT_TEST_TENANT}
mkdir -p ${TENANT_PERF_LOG_DIR}

date
# start the density perf test
# ? do we need --delete-namespace=false ??
echo "./perf-tests/clusterloader2/run-e2e.sh --nodes=${KUBEMARK_NUM_NODES} --provider=kubemark --kubeconfig=../../test/kubemark/resources/kubeconfig.kubemark-proxy --report-dir=${TENANT_PERF_LOG_DIR} --testconfig=testing/density/config.yaml --testoverrides=./testing/experiments/disable_pvs.yaml > ${TENANT_PERF_LOG_DIR}/perf-run.log  2>&1 & "
./perf-tests/clusterloader2/run-e2e.sh --nodes=${KUBEMARK_NUM_NODES} --provider=kubemark --kubeconfig=../../test/kubemark/resources/kubeconfig.kubemark-proxy --report-dir=${TENANT_PERF_LOG_DIR} --testconfig=testing/density/config.yaml --testoverrides=./testing/experiments/disable_pvs.yaml > ${TENANT_PERF_LOG_DIR}/perf-run.log  2>&1 &

test_job=$!
wait ${test_job} || ( echo "failed to start density test!. Aborting..."; return 4 )

return 111
date
echo "shuting down kubemark clusters ..."
./test/kubemark/stop-kubemark.sh 
echo "tearing down admin cluster ..."
./cluster/kube-down.sh
echo "system cleans up. Au revoir :)"
date
