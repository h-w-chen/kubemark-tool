if [[ -z ${RUN_PREFIX} ]]; then
  echo "env vars not properly set; RUN_PREFIX should be specified"
  exit 1
fi

KUBEMARK_ENV_LOG_DIR=~/logs/perf-test/gce-10000/arktos/${RUN_PREFIX}/logs_density
mkdir -p ${KUBEMARK_ENV_LOG_DIR}
cd ${KUBEMARK_ENV_LOG_DIR}

export GCE_PROJECT=workload-controller-manager GCE_REGION=us-central1-b SCALEOUT_CLUSTER=true SCALEOUT_TP_COUNT=5 SCALEOUT_RP_COUNT=5
bash ~/arktos-tool/logcollection/logcollection.sh
