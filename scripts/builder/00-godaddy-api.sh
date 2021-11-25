#!/bin/bash
set -e
set -u

function gd_api() {
    local my_method="${1}"
    local my_path="${2}"
    local my_json="${3:-}"

    if [[ -n ${my_json} ]]; then
        curl -fsSL -X "${my_method}" "https://api.godaddy.com${my_path}" \
            -H "Authorization: sso-key ${GODADDY_API_KEY}:${GODADDY_API_SECRET}" \
            -H "Content-Type: application/json" \
            -d "${my_json}"
    else
        curl -fsSL -X "${my_method}" "https://api.godaddy.com${my_path}" \
            -H "Authorization: sso-key ${GODADDY_API_KEY}:${GODADDY_API_SECRET}"
    fi
}
