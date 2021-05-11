if [[ -z $1 ]]; then
  echo "target machine is expected but not provided"
  exit 1
fi

target=$1
gcloud compute scp --recurse --zone "us-central1-a" --project "workload-controller-manager" ~/hw-env-vars.sh ${target}:~/

