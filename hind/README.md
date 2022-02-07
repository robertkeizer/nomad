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

# copy wildcard cert files for your domain on the VM you want to run this on to: /etc/fabio/ssl/
# name the pair of files like:
#    example.com-cert.pem
#    example.com-key.pem
#
# suggest perms: xxxx
# -r--r--r-- 1 root   root  example.com-cert.pem
# -r--r--r-- 1 root   root  example.com-key.pem

# fire off the container in the background
docker run --net=host --privileged -v /var/run/docker.sock:/var/run/docker.sock --name hind -d hind
```

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
