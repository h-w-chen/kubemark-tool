if [[ -z $1 ]]; then
  echo test tenant is expected but not provided
  exit 1
fi

if [[ -z ${RUN_PREFIX} ]]; then
  echo "seems env setting not proper; no RUN_PREFIX was defined"
  exit 1
fi

SCALEOUT_TEST_TENANT=$1
#RUN_PREFIX=newsche-042821-5x5x10k 
PERF_LOG_DIR=~/logs/perf-test/gce-10000/arktos/${RUN_PREFIX}/${SCALEOUT_TEST_TENANT}
mkdir -p ${PERF_LOG_DIR}

SCALEOUT_TEST_TENANT=${SCALEOUT_TEST_TENANT} RUN_PREFIX=${RUN_PREFIX} PERF_LOG_DIR=${PERF_LOG_DIR} nohup perf-tests/clusterloader2/run-e2e.sh --nodes=10000 --provider=kubemark --kubeconfig=/home/sonyali/go/src/k8s.io/arktos/test/kubemark/resources/kubeconfig.kubemark-proxy --report-dir=${PERF_LOG_DIR} --testconfig=testing/density/config.yaml --testoverrides=./testing/experiments/disable_pvs.yaml > ${PERF_LOG_DIR}/perf-run.log  2>&1  &
