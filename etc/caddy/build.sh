#!/bin/zsh -ex

# archive.org review app cluster seems to "flap" a lot w/ spurious `consul` "updates".
# So avoid too many processing loops and reloads too often
trap "{ sleep 25 }" EXIT


source /etc/caddy/env

export FQDN=${FQDN?}
export TCP_DOMAIN=${TCP_DOMAIN?}
export TRUSTED_PROXIES=${TRUSTED_PROXIES:="private_ranges"}

# wget -qO- 'http://127.0.0.1:8500/v1/catalog/services' |jq .



# xxx http.ctmpl needs to handle http only ports
# xxx telnet services-scribe-c2.code.archive.org 7777  # TCP

cd /etc/caddy
touch tmp.cad
(
  echo '
{
	on_demand_tls {
		# ask /
		interval 1m
		burst 10
	}
}'
  # Optional `base.ctmpl` file that an administrator may elect to use -- and we'll include it
  cat base.ctmpl 2>/dev/null  ||  echo
  cat http.ctmpl
) >| http-base.ctmpl
consul-template -template http-base.ctmpl:tmp.cad -once

caddy fmt tmp.cad | caddy --config /dev/stdin adapt —adapter Caddyfile | jq . >| http.json




touch tmp.json
consul-template -template tcp.ctmpl:tmp.json -once

cat tmp.json | jq . >| tcp.json



jq -s '.[0] * .[1]' tcp.json http.json >| Caddyfile.json


/usr/bin/caddy-plus-tcp reload --config /etc/caddy/Caddyfile.json --force


# not related directly -- but anytime deploys update, might as well ensure nomad TLS files
# are up-to-date since caddy mints and auto-updates the https certs files
/nomad/bin/nomad-tls.sh


echo SUCCESS
