#!/bin/bash
set -e
set -u

my_zone_id=""

function cf_api() {
    local my_method="${1}"
    local my_path="${2}"
    local my_json="${3:-}"

    if [[ -n ${my_json} ]]; then
        curl -fsSL -X "${my_method}" "https://api.cloudflare.com/client${my_path}" \
            -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "${my_json}"
    else
        curl -fsSL -X "${my_method}" "https://api.cloudflare.com/client${my_path}" \
            -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}"
    fi
}

function get_ cf_api GET "/v4/accounts?page=1&per_page=20&direction=desc" |
    jq
# &name=${my_zone}
#     -H "X-Auth-Email: user@example.com" \
#     -H "X-Auth-Key: example-45079dac9320b638f5e225cf483cc5cfdda41" \

cf_api GET "/v4/zones?name=${my_zone}&status=active&page=1&per_page=20&order=status&direction=desc&match=all" |
    jq

my_zone_id="$(curl -X GET "https://api.cloudflare.com/client/v4/zones?name=${my_zone}&status=active&page=1&per_page=20&order=status&direction=desc&match=all" \
    -H "Authorization: Bearer ${my_token}" |
    jq -r '.result[0].id')"

#     -H "Content-Type: application/json"
# &account.id=01a7362d577a6c3019a474fd6f485823&account.name=Demo Account

my_sub="demo.savvi.legal"
curl -X GET "https://api.cloudflare.com/client/v4/zones/${my_zone_id}/dns_records?type=A&name=${my_sub}&page=1&per_page=20&order=type&direction=desc&match=all" \
    -H "Authorization: Bearer ${my_token}" |
    jq
# &name=${my_sub}${my_zone}
# &content=127.0.0.1&proxied=undefined
