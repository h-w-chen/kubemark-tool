#!/bin/bash
# Credit: this script is based on https://github.com/sonyafenge/arktos-tool/blob/master/perftools/Howtorunperf-tests-scaleout.md
# purpose: to perf test scale-out mTP/nRP system / scale-up (single cluster) system
# this script is supposed to be sourced.
# usage:
#        export TEST_TYPE=load #default to density
#        . <script> <run-name> <hollow-nodes-per-rp> <tp-num> <rp-num>

[[ -z $1 ]] && echo "MUST specify RUN_PREFIX in format like etcd343-0312-1x500" && return 1
## KUBEMARK_NUM_NODES is the hollow nodes of ONE RP only; the total nodes are n * KUBEMARK_NUM_NODES
[[ -z $2 ]] && echo "MUST specify KUBEMARK_NUM_NODES in one of supported values 1, 2, 100, 500, 1000, 10000" && return 2

export SCALEOUT_CLUSTER=true
declare -i tp_reps=${3:-1}
[[ $tp_reps -eq 0 ]] && { echo "Run in scale-up (not scale-out) mode instead."; unset SCALEOUT_CLUSTER; }

declare -i rp_reps=${4:-${tp_reps}}
echo "run ${1}: tp ${tp_reps}; rp ${rp_reps}, each rp has hollow nodes: ${2}"

case $tp_reps in
  0) ;;
  1)
  tenants=("" "arktos")
  ;;
  2)
  tenants=("" "arktos" "zeta")
  ;;
  3)
  tenants=("" "arktos" "mercury" "zeta")
  ;;
  *)
  echo "not supported tp_reps."
  return -1;
esac

test_jobs=()

declare PRE="zz-" 	## zz- to ensure perf test resouce names come after regular used ones
declare RUN_ID=$1
export RUN_PREFIX=${PRE}$1
export KUBEMARK_NUM_NODES=$2


function calc_gce_resource_params() {
  local size=${1}
  case "$size" in
  [12])
  export MASTER_DISK_SIZE=100GB 
  export MASTER_ROOT_DISK_SIZE=100GB
  export MASTER_SIZE=n1-standard-4
  export NODE_SIZE=n1-standard-4
  export NODE_DISK_SIZE=100GB
  ;;
  [1-4]00)
  export MASTER_DISK_SIZE=200GB 
  export MASTER_ROOT_DISK_SIZE=200GB
  export MASTER_SIZE=n1-highmem-8
  export NODE_SIZE=n1-highmem-16
  export NODE_DISK_SIZE=200GB
  ;;
  [5-9]00)
  export MASTER_DISK_SIZE=200GB 
  export MASTER_ROOT_DISK_SIZE=200GB
  export MASTER_SIZE=n1-highmem-32
  export NODE_SIZE=n1-highmem-16
  export NODE_DISK_SIZE=200GB
  ;;
  1000)
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

declare -i total_hollow_nodes=(${rp_reps}*${KUBEMARK_NUM_NODES})
calc_gce_resource_params ${total_hollow_nodes}
if [[ $? -ne 0 ]]; then
	echo "MUST specify KUBEMARK_NUM_NODES in one of supported values 1, 2, 100, 500, 1000, 10000"
	return 3
fi

# https://github.com/fabric8io/kansible/blob/master/vendor/k8s.io/kubernetes/docs/devel/kubemark-guide.md
# ~17.5 hollow-node pods per cpu core ==> 16 cores: 110 hollow-nodes
#declare -x -i NUM_NODES=("${KUBEMARK_NUM_NODES}" + 110 -1)/110
declare -x -i NUM_NODES=("${total_hollow_nodes}" + 100 - 1)/100		## arktos team experience; may consider give 1 nuffer in case of 100/500
[[ ${total_hollow_nodes} -lt 499 ]] && NUM_NODES=${NUM_NODES}+1

echo "${NUM_NODES} admin minion nodes, total hollow nodes ${total_hollow_nodes}"
export PREEMPTIBLE_NODE=${PREEMPTIBLE_NODE:-true}
#export USE_INSECURE_SCALEOUT_CLUSTER_MODE=false		## better avoid insecure mode currently buggy?
export SCALEOUT_TP_COUNT=${tp_reps}			## TP number
export SCALEOUT_RP_COUNT=${rp_reps}			## RP number
export CREATE_CUSTOM_NETWORK=true			## gce env isolaation
export KUBE_GCE_PRIVATE_CLUSTER=true
export KUBE_GCE_ENABLE_IP_ALIASES=true
export KUBE_GCE_NETWORK=${RUN_PREFIX}
export KUBE_GCE_INSTANCE_PREFIX=${RUN_PREFIX}		## for kube-up/down to identify GCP resources
export KUBE_GCE_ZONE=${KUBE_GCE_ZONE-us-central1-b}

export ENABLE_KCM_LEADER_ELECT=false
export ENABLE_SCHEDULER_LEADER_ELECT=false
export ETCD_QUOTA_BACKEND_BYTES=8589934592		## etcd 8GB data
#export SHARE_PARTITIONSERVER=false
export LOGROTATE_FILES_MAX_COUNT=50			## if need huge pile of logs, consider increase to 200
export LOGROTATE_MAX_SIZE=200M
export KUBE_ENABLE_APISERVER_INSECURE_PORT=true		## to enable prometheus
export KUBE_ENABLE_PROMETHEUS_DEBUG=true
export KUBE_ENABLE_PPROF_DEBUG=true
export TEST_CLUSTER_LOG_LEVEL=--v=2
export HOLLOW_KUBELET_TEST_LOG_LEVEL=--v=2
export GOPATH=$HOME/go

## for perf test only - speed up deleting pods (by doubling GC controller QPS)
export KUBE_FEATURE_GATES=ExperimentalCriticalPodAnnotation=true,QPSDoubleGCController=true #,QPSDoubleRSController=true
## below controls KCM + sched QPS; use them in caution
export KUBE_CONTROLLER_EXTRA_ARGS="--kube-api-qps=100 --kube-api-burst=150"
export KUBE_SCHEDULER_EXTRA_ARGS="--kube-api-qps=200 --kube-api-burst=300"
export KUBE_APISERVER_EXTRA_ARGS="--max-mutating-requests-inflight=20000 --max-requests-inflight=40000"
## more general args for master components; keep here for reference
#KUBE_CONTROLLER_EXTRA_ARGS=" --kube-api-qps=2000 --kube-api-burst=4000 --concurrent-deployment-syncs=500 --concurrent-replicaset-syncs=500 --concurrent_rc_syncs=500 --concurrent-endpoint-syncs=500 --concurrent-gc-syncs=2000 --concurrent-namespace-syncs=1000 --concurrent-resource-quota-syncs=500 --concurrent-service-syncs=100 --concurrent-serviceaccount-token-syncs=500 --concurrent-ttl-after-finished-syncs=500"
#KUBE_SCHEDULER_EXTRA_ARGS=" --kube-api-qps=2000 --kube-api-burst=4000"

export SHARED_CA_DIRECTORY=/tmp/${USER}/ca
mkdir -p ${SHARED_CA_DIRECTORY}

echo "------------------------------------------"
echo "step 1. starting admin cluster ... $(date)"
./cluster/kube-up.sh

is_kube_up=$?
if [[ "${is_kube_up}" == "1" ]]; then
    return 5
elif [[ "${is_kube_up}" == "2" ]]; then
    echo "waring: fine to continue"
fi

echo "------------------------------------------"
echo "step 2: starting kubemark clusters ... $(date)"
./test/kubemark/start-kubemark.sh

# optional: sanity check

perf_log_root=$HOME/logs/perf-test/gce-${total_hollow_nodes}/arktos/${RUN_PREFIX}

# start perf tool
function start_perf_test() {
  local tenant=$1
  local kube_config=$2
  local test_type=${TEST_TYPE:-density}
  ## todo: change clusterload code to fix the rp access bug
  local kube_config_proxy=$PWD/test/kubemark/resources/kubeconfig.kubemark-proxy
  perf_log_folder="${perf_log_root}/${tenant}"
  echo "perf log folder: ${perf_log_folder}"
  mkdir -p ${perf_log_folder}

  # create the test tenant in kubemark TP cluster
  ./_output/dockerized/bin/linux/amd64/kubectl --kubeconfig=${kube_config} create tenant ${tenant}

  # ? do we need --delete-namespace=false ??
  declare -i nodes=${KUBEMARK_NUM_NODES}
  if [[ ${tp_reps} -ne 0 ]]; then # scale-out multi-tp/rp cluster
	  nodes=(${total_hollow_nodes}/${tp_reps}+99)/100*100
  fi

  echo env SCALEOUT_TEST_TENANT=${tenant} ./perf-tests/clusterloader2/run-e2e.sh --nodes=${nodes} --provider=kubemark --kubeconfig=${kube_config_proxy} --report-dir=${perf_log_folder} --testconfig=testing/${test_type}/config.yaml --testoverrides=./testing/experiments/disable_pvs.yaml
  env SCALEOUT_TEST_TENANT=${tenant} ./perf-tests/clusterloader2/run-e2e.sh --nodes=${nodes} --provider=kubemark --kubeconfig=${kube_config_proxy} --report-dir=${perf_log_folder} --testconfig=testing/${test_type}/config.yaml --testoverrides=./testing/experiments/disable_pvs.yaml > ${perf_log_folder}/perf-run.log  2>&1 &
  test_job=$!
  test_jobs+=($test_job)
}

echo "------------------------------------------"
echo "step 3: run perf test suite per tp ... $(date)"
for t in $(seq 1 $tp_reps); do
  start_perf_test ${tenants[$t]} $PWD/test/kubemark/resources/kubeconfig.kubemark.tp-${t} 
done

if [[ $tp_reps -eq 0 ]]; then #non scale-out; single master for all
  start_perf_test ${tenants[$t]} $PWD/test/kubemark/resources/kubeconfig.kubemark.tp
fi

echo "waiting for perf test suites done..."
echo "background jobs: ${test_jobs[@]}"
for t in ${test_jobs[@]}; do
  wait $t || ( echo "failed to start density test. Aborting..."; return 4 )
done

echo "------------------------------------------"
#return 0 ## to uncomment it in local controlled run

echo "step 4: per test suites are done; collecting logs ... $(date)"
pushd ${perf_log_root}
env GCE_REGION=${KUBE_GCE_ZONE} bash ~/arktos-tool/logcollection/logcollection.sh
## rough check of log
### find . -name "minion-*" -type d | xargs -I{} wc -l {}/kubelet.log
wc -l minion-*/kubelet.logs || (echo "log data seems incomplete. Aborting..."; return 5;)
popd

echo "------------------------------------------"
echo "step 5: cleaning up GCP test resources ... $(date)"
SCRIPT=$(realpath -P ./kubemark-setup.sh)
SCRIPTPATH=`dirname $SCRIPT`
bash ${SCRIPTPATH}/gcp-cleanup.sh ${RUN_ID}
echo "------------------------------------------"
echo "step 6: system has been cleaned up. Au revoir :) $(date)"

#echo "------------------------------------------"
#echo "step 5: shuting down kubemark clusters ... $(date)"
#./test/kubemark/stop-kubemark.sh
#echo "------------------------------------------"
#echo "step 6: tearing down admin cluster ... $(date)
#./cluster/kube-down.sh
#echo "------------------------------------------"
#echo "step 7: system has been cleaned up. Au revoir :) $(date)"

echo "local cleanup of kubemark-config files"
rm test/kubemark/resources/kubeconfig.*

