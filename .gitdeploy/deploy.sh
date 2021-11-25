#!/bin/bash
# shellcheck disable=SC1090,SC1091
set -e
set -u

GIT_REF_NAME="${GIT_REF_NAME:-}"
GIT_REPO_ID="${GIT_REPO_ID:-EMPTY_REPO_ID}"

# See the Git Credentials Cheat Sheet
# https://coolaj86.com/articles/vanilla-devops-git-credentials-cheatsheet/
#git config --global url."https://api:${GITHUB_TOKEN}@github.com/savvi-legal/".insteadOf "https://github.com/savvi-legal/"
#git clone --branch "${GIT_REF_NAME}" "${GIT_CLONE_URL}" "${my_project}"

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
    my_env="${1}"

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

    bash ./scripts/builder/00-provision-vps.sh \
        "${my_domain}" "${my_zone}"

    local my_hostname="app@${my_domain}.${my_zone}"
    #ssh-keygen -f ~/.ssh/known_hosts -R "${my_hostname}"
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "${my_hostname}" 'mkdir -p ~/srv/'

    #shellcheck disable=SC2153
    rsync -av --delete --inplace --exclude=.git \
        ./ "${my_hostname}":~/srv/"${GIT_REPO_NAME}"/

    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "${my_hostname}" "
            source ~/.config/envman/load.sh
            rm -f ~/.env
            echo 'CLOUDFLARE_API_TOKEN=${CLOUDFLARE_API_TOKEN:-}' >> ~/.env
            echo 'GODADDY_API_KEY=${GODADDY_API_KEY:-}' >> ~/.env
            echo 'GODADDY_API_TOKEN=${GODADDY_API_TOKEN:-}' >> ~/.env
            echo 'PORT=5227' >> ~/.env
            pushd ~/srv/'${GIT_REPO_NAME}'/
            bash scripts/deploy.sh '${my_env}' '${my_domain}' '${my_zone}' '${GIT_REPO_NAME}'
            popd
        "
}

check_builder_deps
build

export DIGITALOCEAN_TOKEN

if [[ "production" == "${GIT_REF_NAME}" ]]; then

    source_all 'production'
    export CLOUDFLARE_API_TOKEN
    source scripts/builder/00-cloudflare-api.sh
    deploy production "${DNS_SUBDOMIN}" "${DNS_ZONE}"

elif [[ "dev" == "${GIT_REF_NAME}" ]]; then

    source_all 'development'
    export GODADDY_API_KEY
    export GODADDY_API_SECRET
    source scripts/builder/00-godaddy-api.sh
    deploy dev "${DNS_SUBDOMIN}" "${DNS_ZONE}"

else
    source scripts/builder/00-godaddy-api.sh
    # TODO figure out the build
fi
