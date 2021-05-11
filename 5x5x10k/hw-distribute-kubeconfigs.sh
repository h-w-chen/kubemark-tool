if [[ -z $1 ]]; then
  echo "target machine is expected but not provided"
  exit 1
fi
 
target=$1
## following files should be copied
## test/kubemark/resources/kubeconfig.kubemark-proxy
## test/kubemark/resources/kubeconfig.kubemark.rp-1
## test/kubemark/resources/kubeconfig.kubemark.rp-2
## test/kubemark/resources/kubeconfig.kubemark.rp-3
## test/kubemark/resources/kubeconfig.kubemark.rp-4
## test/kubemark/resources/kubeconfig.kubemark.rp-5
## test/kubemark/resources/kubeconfig.kubemark.tp-1
## test/kubemark/resources/kubeconfig.kubemark.tp-2
## test/kubemark/resources/kubeconfig.kubemark.tp-3
## test/kubemark/resources/kubeconfig.kubemark.tp-4
## test/kubemark/resources/kubeconfig.kubemark.tp-5
gcloud compute scp --zone "us-central1-a" --project "workload-controller-manager" test/kubemark/resources/kubeconfig.kubemark* ${target}:~/go/src/k8s.io/arktos/test/kubemark/resources/

