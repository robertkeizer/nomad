#!/bin/zsh -ex

source /etc/caddy/env

export HOSTNAME=${HOSTNAME?}

# wget -qO- 'http://127.0.0.1:8500/v1/catalog/services' |jq .


# xxx http.ctmpl needs to handle http only ports

cd /etc/caddy
touch tmp.cad
consul-template -template /etc/caddy/http.ctmpl:tmp.cad -once

caddy fmt tmp.cad | caddy --config /dev/stdin adapt —adapter Caddyfile | jq . >| http.json




touch tmp.json
consul-template -template /etc/caddy/tcp.ctmpl:tmp.json -once

cat tmp.json | jq . >| tcp.json




jq -s '.[0] * .[1]' tcp.json http.json >| Caddyfile.json
