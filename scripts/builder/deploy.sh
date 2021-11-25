#!/bin/bash
set -e
set -u

export GIT_REF_NAME="dev"
export GIT_REPO_ID="savvi-legal/libreoffice-as-a-service"
export GIT_REPO_NAME="libreoffice-as-a-service"
export DNS_SUBDOMIN=dev-lass
export DNS_ZONE=savvy.legal

bash .gitdeploy/deploy.sh
