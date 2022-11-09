#!/bin/zsh -ex

source /etc/caddy/env

export HOSTNAME=${HOSTNAME?}

# wget -qO- 'http://127.0.0.1:8500/v1/catalog/services' |jq .


# xxx http.ctmpl needs to handle http only ports

touch tmp.cad
consul-template -template ~/dev/nomad/etc/caddy/http.ctmpl:tmp.cad -once

caddy fmt tmp.cad | caddy --config /dev/stdin adapt —adapter Caddyfile | jq . >| http.json




touch tmp.json
consul-template -template ~/dev/nomad/etc/caddy/tcp.ctmpl:tmp.json -once

cat tmp.json | jq . >| tcp.json




jq -s '.[0] * .[1]' tcp.json http.json >| merged.json



# rm  tmp.cad tmp.json  xxx
