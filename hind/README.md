# HinD - Hashstack IN Docker

Installs `nomad`, `consul`, and `fabio` (load balancer) together as a mini cluster running inside a `docker` container.

Nomad jobs will run as `docker` containers on the VM itself, orchestrated by `nomad`, leveraging `docker.sock`.

## Minimal requirements:
- VM with `docker` daemon
- VM you can `ssh` and `sudo`
- if using a firewall (like `ferm`, etc.) make sure the following ports are open from the VM to the world:
  - 443  - https
  - 80   - http  (load balancer will auto-upgrade/redir to https)
  - 4646 - access to `nomad`

## https
The ideal experience is that you point a dns wildcard at the IP address of the VM running your `hind` system.

This allows automatically-created hostnames from git group/organization + repository name + branch name to "just work".

For example, `*.example.com` DNS wildcard will allow https://myteam-my-repo-name-my-branch.example.com to "just work".

(Presently) you then need (ideally a _https_ wildcard cert (2 files)) that can be added (dynamically) to `fabio`.  `fabio` will then do http => https automatic 301 redirects and https validation and termination (downgrading traffic to talk to your deployments over simply http).

Simply copy in your https wildcard cert file pair into this folder on your VM: `/etc/fabio/ssl/`,
named like:
```
example.com-cert.pem
example.com-key.pem
```

We are working on integrating [caddy](https://caddyserver.com) (which incorporates `zerossl` and Let's Encrypt to on-demand create single host https certs as traffic arrives at your box.

(Then you won't have to deal with renewing https wildcard cert(s) yourself, periodically. ;-)


## Setup and run
We'll use this as our `Dockerfile`: [../Dockerfile.hind](../Dockerfile.hind)

```bash
git clone https://gitlab.com/internetarchive/nomad.git
cd nomad

# build locally
docker build --network=host -t hind -f Dockerfile.hind  .

# fire off the container in the background
docker run --net=host --privileged -v /var/run/docker.sock:/var/run/docker.sock --restart=always --name hind -d hind
```

Copy wildcard cert files for your domain on the VM you want to run this on to: `/etc/fabio/ssl/`

Name the pair of files like:
- `example.com-cert.pem`
- `example.com-key.pem`

suggest perms: xxxx
```bash
-r--r--r-- 1 root   root  example.com-cert.pem
-r--r--r-- 1 root   root  example.com-key.pem
```


## Setting up jobs
We suggest you use the same approach mentioned in [../README.md](../README.md) which will ultimately use a templated [../project.nomad](../project.nomad) file.  However, since we are running `nomad` and `consul` inside a docker container, you will need to add the following to your project's `.gitlab-ci.yml` files:
```yaml
variables:
  NOMAD_VAR_NETWORK_MODE: 'host'
  NOMAD_VAR_PORTS: '{ -1 = "http" }'
```
This will make your container's main http port be dynamic (and not fixed to something like 80 or 5000) so that multiple deployments can all run using different ports.

Simply setup your `Dockerfile` to read the environment variable `$NOMAD_PORT_http` and have your webserver/daemon listen on that port.  `$NOMAD_PORT_http` gets set by `nomad` when your container starts up, to the random port it picked for your daemon to listen on.

## Nomad credentils
Get your nomad access credentials (`NOMAD_ADDR` and `NOMAD_TOKEN`) from a shell on the VM, so you can run `nomad status` anywhere you have downloaded `nomad` binary (include home mac/laptop etc.)
```bash
docker exec -it hind zsh -c 'cat /root/.config/nomad' | perl -pe s/localhost/$(hostname -f)/
```

You can also open the `NOMAD_ADDR` (above) in a browser and enter in your `NOMAD_TOKEN`

## GUI, Monitoring, Interacting
- see [../README.md](../README.md) for lots of ways to work with your deploys.  There you can find details on how to check a deploy's status and logs, `ssh` into it, customized deploys, and more.
- You can setup an `ssh` tunnel thru your VM so that you can see `consul` and `fabio` in a browser, eg:

```bash
nom-tunnel () {
  [ "$NOMAD_ADDR" = "" ] && echo "Please set NOMAD_ADDR environment variable first" && return
  local HOST=$(echo "$NOMAD_ADDR" | sed 's/:4646\/*$//' |sed 's/^https*:\/\///')
  ssh -fNA -L 8500:$HOST:8500 -L 9998:$HOST:9998 $HOST
}
```

- Then run `nom-tunnel` and you can see with a browser:
  - `fabio`  http://localhost:9998/
  - `consul` http://localhost:8500/
