#!/bin/zsh -ex

# archive.org review app cluster seems to "flap" a lot w/ spurious `consul` "updates".
# So avoid too many processing loops and reloads too often
trap "{ sleep 25 }" EXIT


source /etc/caddy/env

export HOSTNAME=${HOSTNAME?}
export TCP_DOMAIN=${TCP_DOMAIN?}

# wget -qO- 'http://127.0.0.1:8500/v1/catalog/services' |jq .



# xxx http.ctmpl needs to handle http only ports
# xxx telnet services-scribe-c2.code.archive.org 7777  # TCP

cd /etc/caddy
touch tmp.cad
consul-template -template /etc/caddy/http.ctmpl:tmp.cad -once

caddy fmt tmp.cad | caddy --config /dev/stdin adapt —adapter Caddyfile | jq . >| http.json




touch tmp.json
consul-template -template /etc/caddy/tcp.ctmpl:tmp.json -once

cat tmp.json | jq . >| tcp.json



jq -s '.[0] * .[1]' tcp.json http.json >| Caddyfile.json


/usr/bin/caddy-plus-tcp reload --config /etc/caddy/Caddyfile.json --force


echo SUCCESS
