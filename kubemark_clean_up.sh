#!/bin/bash

[[ "$1" == "" ]] && ( echo "must provide param of the prefix key" && exit 1 )

declare KEYWORD=${1}
declare PRE="zz-"
declare PRE_KEY="${PRE}${KEYWORD}"

echo "1. cleaning up instance groups..."
gcloud compute instance-groups list --filter="name~'^${PRE_KEY}.*'" --format="value(name)" | xargs -r gcloud compute instance-groups managed delete --quiet
echo "2. cleaning up vm..."
gcloud compute instances list --filter="name~'^${PRE_KEY}.*'" --format="value(name)" | xargs -r gcloud compute instances delete --quiet
echo "3. cleaning up instance templates..."
gcloud compute instance-templates list --filter="name~'^${PRE_KEY}.*'" --format="value(name)" | xargs -r gcloud compute instance-templates delete --quiet
echo "4. cleaning up firewall rules..."
gcloud compute firewall-rules list --filter="network~'${PRE_KEY}.*'" --format="value(id)" | xargs -r gcloud compute firewall-rules delete --quiet
echo "5. cleaning up routers..."
gcloud compute routers list --filter="network~'${PRE_KEY}.*'" --format="value(id)" | xargs -r gcloud compute routers delete --quiet
echo "6. cleaning up ip addresses..."
gcloud compute addresses list --filter="name~'${PRE_KEY}.*'" --format="value(name)" | xargs -r gcloud compute addresses delete --quiet
echo "7. cleaning up subnets..."
gcloud compute networks subnets list --filter="network~'${PRE_KEY}.*'" --format="value(id)" | xargs -r gcloud compute networks subnets delete --quiet
echo "8. cleaning up vpc network..."
gcloud compute networks list --filter="name~'^${PRE_KEY}.*'" --format="value(name)" | xargs -r gcloud compute networks delete --quiet

echo "all resources prefixed with ${PRE_KEY} have been clened up."

