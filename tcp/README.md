# TCP with Caddy

https://github.com/mholt/caddy-l4
( from https://caddy.community/t/reverse-proxy-any-tcp-connection-for-database-connections/12732/2 )

[tcp.json](tcp.json) -- verify by running [echo.js](echo.js)


```sh
caddy fmt /etc/caddy/Caddyfile |caddy --config /dev/stdin adapt —adapter Caddyfile |jq . >| base.json

jq -s '.[0] * .[1]' base.json tcp.json >| merged.json

sudo ~tracey/scripts/caddy run --config merged.json

```

xxx make sample `Caddyfile` of: normal case; alt ports via http and https; http only; tcp
then export it to `Caddyfile.json` then
```sh
consul-template -template ~/dev/nomad/etc/caddy/Caddyfile.json.ctmpl:out.json -once; cat out.json|jq . >| C.json
colordiff Caddyfile.json C.json
```
