#!/usr/bin/env bash

set -Euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

while getopts p: flag
do
    case "${flag}" in
        p) PROJECT_ID=${OPTARG};;
    esac
done

echo "::Variable set::"
echo "PROJECT_ID: ${PROJECT_ID}"

echo "Creating a global public IP for the ASM GW."
if [[ $(gcloud compute addresses describe asm-gw-ip --global --project ${PROJECT_ID}) ]]; then
  echo "ASM GW IP already exists."
else
  echo "Creating ASM GW IP."
  gcloud compute addresses create asm-gw-ip --global --project ${PROJECT_ID}
fi
export ASM_GW_IP=`gcloud compute addresses describe asm-gw-ip --global --format="value(address)"`
echo -e "GCLB_IP is ${ASM_GW_IP}"

echo "Creating gcp endpoints for each demo app."
cat <<EOF > rollout-demo-openapi.yaml
swagger: "2.0"
info:
  description: "Cloud Endpoints DNS"
  title: "Cloud Endpoints DNS"
  version: "1.0.0"
paths: {}
host: "rollout-demo.endpoints.${PROJECT_ID}.cloud.goog"
x-google-endpoints:
- name: "rollout-demo.endpoints.${PROJECT_ID}.cloud.goog"
  target: "${ASM_GW_IP}"
EOF

gcloud endpoints services deploy rollout-demo-openapi.yaml --project ${PROJECT_ID}

cat <<EOF > whereami-openapi.yaml
swagger: "2.0"
info:
  description: "Cloud Endpoints DNS"
  title: "Cloud Endpoints DNS"
  version: "1.0.0"
paths: {}
host: "whereami.endpoints.${PROJECT_ID}.cloud.goog"
x-google-endpoints:
- name: "whereami.endpoints.${PROJECT_ID}.cloud.goog"
  target: "${ASM_GW_IP}"
EOF

gcloud endpoints services deploy whereami-openapi.yaml --project ${PROJECT_ID}

cd gke-poc-config-sync
find ./ -type f -exec sed -i '' -e "s/fleets-acm-demo00/${PROJECT_ID}/g" {} +
find ./ -type f -exec sed -i '' -e "s/34.117.163.119/${ASM_GW_IP}/g" {} +
# find ./ -type f -exec sed -i '' -e "s|{{SYNC_REPO}}|${REPO}|g" {} +

git init -b main
git add . && git commit -m "Initial commit"
git push 

echo "The Fleet has been configured"