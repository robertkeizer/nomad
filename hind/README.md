# HinD - Hashstack IN Docker

Installs `nomad`, `consul`, and `fabio` (load balancer) together as a mini cluster running inside a `docker` container.

Nomad jobs will run as `docker` containers on the VM itself, orchestrated by `nomad`, leveraging `docker.sock`.

Minimal requirements:
- VM with `docker` daemon
- VM you can `ssh` and `sudo`
- if using a firewall (like `ferm`, etc.) make sure the following ports are open to the world:
  - 443  - https
  - 80   - http
  - 4646 - access to `nomad`


```bash
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

docker run --net=host --privileged -v /var/run/docker.sock:/var/run/docker.sock --name hind --rm -it hind zsh

docker run --net=host --privileged -v /var/run/docker.sock:/var/run/docker.sock --name hind -d hind
```
