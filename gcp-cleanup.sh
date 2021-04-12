#!/bin/bash
# sample usage:
#     env GCP_ZONE=us-central1-a GCP_REGION=us-central1 KUBEMARK_PRE="poc430-" bash ./gcp-cleanup.sh "210412-2z3x100"

shopt -s expand_aliases

[[ "$1" == "" ]] && ( echo "must provide param of the prefix key" && exit 1 )

# env var GCP_ZONE limits the scope of cleanup to specific zone; by default the default zone of gcloud config
declare zone=${GCP_ZONE:-$(gcloud config get-value compute/zone)}
declare region=${GCP_REGION:-$(gcloud config get-value compute/region)}
declare PRE=${KUBEMARK_PRE:-zz-}

declare KEYWORD=${1}
declare PRE_KEY="${PRE}${KEYWORD}"

alias xargsp='xargs -r -n20 -P0'

echo "1. cleaning up instance groups..."
gcloud compute instance-groups list --filter="name~'^${PRE_KEY}.*' zone:(${zone})" --format="value(name)" | xargsp gcloud compute instance-groups managed delete --quiet --zone=${zone}
echo "2. cleaning up vm..."
gcloud compute instances list --filter="name~'^${PRE_KEY}.*' zone:(${zone})" --format="value(name)" | xargsp gcloud compute instances delete --quiet --zone=${zone}
echo "3. cleaning up instance templates..."
gcloud compute instance-templates list --filter="name~'^${PRE_KEY}.*'" --format="value(name)" | xargsp gcloud compute instance-templates delete --quiet
echo "4. cleaning up firewall rules..."
gcloud compute firewall-rules list --filter="network~'${PRE_KEY}.*'" --format="value(id)" | xargsp gcloud compute firewall-rules delete --quiet
echo "5. cleaning up routers..."
gcloud compute routers list --filter="network~'${PRE_KEY}.*'" --format="value(id)" | xargsp gcloud compute routers delete --quiet
echo "6. cleaning up ip addresses..."
gcloud compute addresses list --filter="name~'${PRE_KEY}.*' region:(${region})" --format="value(name)" | xargsp gcloud compute addresses delete --quiet --region=${region}
echo "7. cleaning up subnets..."
gcloud compute networks subnets list --filter="network~'${PRE_KEY}.*' region:(${region})" --format="value(id)" | xargsp gcloud compute networks subnets delete --quiet --region=${region}
echo "8. cleaning up vpc network..."
gcloud compute networks list --filter="name~'^${PRE_KEY}.*'" --format="value(name)" | xargsp gcloud compute networks delete --quiet
echo "9. cleaning up storages..."
gcloud compute disks list --filter="name~'^${PRE_KEY}.*' zone:(${zone})" --format="value(id)" | xargsp gcloud compute disks delete --quiet --zone=${zone}
gsutil ls gs://kubernetes-staging-00c32ee1ce/ | grep ${PRE_KEY} | xargsp gsutil rm -r

echo "all resources prefixed with ${PRE_KEY} have been clened up."

