if [[ -z $1 ]]; then
  echo remote host is expected but not provided
  exit 1
fi

if [[ -z $2 ]]; then
  echo test tenant is expected but not provided
  exit 1
fi

if [[ -z ${RUN_PREFIX} ]]; then
  echo "seems env setting not proper; no RUN_PREFIX was defined"
  exit 1
fi

SCALEOUT_TEST_HOST=$1
SCALEOUT_TEST_TENANT=$2
PERF_LOG_DIR=~/logs/perf-test/gce-10000/arktos/${RUN_PREFIX}/${SCALEOUT_TEST_TENANT}
gcloud compute scp --recurse --zone "us-central1-a" --project "workload-controller-manager" ${SCALEOUT_TEST_HOST}:${PERF_LOG_DIR} ./

