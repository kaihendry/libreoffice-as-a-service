#!/bin/bash
# shellcheck disable=SC1090,SC1091
set -e
set -u

GIT_REPO_NAME="${GIT_REPO_NAME:-"${1}"}"
GIT_REF_NAME="${GIT_REPO_NAME:-"${2}"}"
my_env="${2:-development}"
DNS_SUBDOMAIN="${DNS_SUBDOMAIN:-"${4}"}"
DNS_ZONE="${DNS_ZONE:-"${4}"}"
API_TOKEN="${API_TOKEN:-"$(openssl rand -hex 10)"}"

function check_builder_deps() {
    if [[ -z "$(command -v webi)" ]]; then
        curl https://webinstall.dev | bash
    fi
    export PATH="$HOME/.local/bin:${PATH}"
}

function build() {
    bash scripts/builder/01-build.sh
}

function source_all() {
    local my_env="${1}"

    source ".env.${my_env}" 2> /dev/null || true
    #shellcheck disable=SC2153
    source ~/envs/"${my_env}"/"${GIT_REPO_NAME}"/env 2> /dev/null || true
    source .env 2> /dev/null || true
    source ../.env 2> /dev/null || true
    source ~/.env 2> /dev/null || true
}

function deploy() {
    local my_env="${1}"
    local my_domain="${2}"
    local my_zone="${3}"

    bash ./scripts/builder/01-provision-vps.sh \
        "${my_domain}" "${my_zone}"

    local my_hostname="app@${my_domain}.${my_zone}"
    #ssh-keygen -f ~/.ssh/known_hosts -R "${my_hostname}"
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "${my_hostname}" 'mkdir -p ~/srv/'

    #shellcheck disable=SC2153
    rsync -e 'ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' \
        -av --delete --inplace --exclude=.git \
        ./ "${my_hostname}":~/srv/"${GIT_REPO_NAME}"/

    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "${my_hostname}" "
            source ~/.config/envman/load.sh
            rm -f ~/.env
            echo 'CLOUDFLARE_API_TOKEN=${CLOUDFLARE_API_TOKEN:-}' >> ./.env
            echo 'GODADDY_API_KEY=${GODADDY_API_KEY:-}' >> ./.env
            echo 'GODADDY_API_SECRET=${GODADDY_API_SECRET:-}' >> ./.env
            pushd ~/srv/'${GIT_REPO_NAME}'/
            echo 'PORT=5227' >> ./.env
            echo 'API_TOKEN=${API_TOKEN:-}' >> ./.env
            bash scripts/deploy.sh '${my_env}' '${my_domain}' '${my_zone}' '${GIT_REPO_NAME}'
            popd
        "
}

check_builder_deps
build

export DIGITALOCEAN_TOKEN

if [[ "production" == "${GIT_REF_NAME}" ]]; then

    echo "Deploying production..."
    source_all 'production'
    export CLOUDFLARE_API_TOKEN
    source scripts/builder/00-cloudflare-api.sh
    deploy production "${DNS_SUBDOMAIN}" "${DNS_ZONE}"

elif [[ "dev" == "${GIT_REF_NAME}" ]]; then

    echo "Deploying development..."
    source_all 'development'
    export CLOUDFLARE_API_TOKEN=""
    export GODADDY_API_KEY
    export GODADDY_API_SECRET
    source scripts/builder/00-godaddy-api.sh
    deploy dev "${DNS_SUBDOMAIN}" "${DNS_ZONE}"

else
    source scripts/builder/00-godaddy-api.sh
    # TODO figure out the build
fi
