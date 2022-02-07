#!/bin/zsh -ex

# Creates a single node nomad cluster, running inside docker.
#
# Assumes you are creating cluster with debian/ubuntu VMs/baremetals,
# that you have ssh and sudo access to.
#
# Current Overview:
#   Installs nomad server and client.
#   Installs consul server and client.
#   Installs load balancer "fabio".

function main() {
  config

  # install & setup stock nomad & consul
  baseline

  # customize nomad & consul
  customize

  finish
}


function config() {
  FIRST=$(hostname -f)

  export  NOMAD_ADDR="http://${FIRST?}:4646" # xxxx we'll use https everywhere once caddy is up...
  export CONSUL_ADDR="http://localhost:8500"
  export  FABIO_ADDR="http://localhost:9998"
  export FIRSTIP=$(host ${FIRST?} | perl -ane 'print $F[3] if $F[2] eq "address"')
  export SCTL=supervisorctl

  # find daemon config files
   NOMAD_HCL=$(dpkg -L nomad  2>/dev/null |egrep ^/etc/ |egrep -m1 '\.hcl$' || echo -n '')
  CONSUL_HCL=$(dpkg -L consul 2>/dev/null |egrep ^/etc/ |egrep -m1 '\.hcl$' || echo -n '')
}


function baseline() {
  cd /tmp

  apt-get -yqq --no-install-recommends install  sudo  rsync  dnsutils  supervisor

  /app/install-docker-ce.sh

  # install binaries and service files
  #   eg: /usr/bin/nomad  /etc/nomad.d/nomad.hcl  /usr/lib/systemd/system/nomad.service

  curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
  apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
  apt-get -yqq update

  apt-get -yqq install  nomad  consul

  config

  # start up uncustomized versions of nomad and consul
  setup-daemons
}


function customize() {
  setup-nomad
  setup-consul

  nomad-env-vars

  set +x
  echo "================================================================================"
  ( set -x; consul members )
  echo "================================================================================"
  ( set -x; nomad server members )
  echo "================================================================================"
  ( set -x; nomad node status )
  echo "================================================================================"
}


function finish() {
  sleep 30

  nomad run /app/etc/fabio.hcl

  echo "

💥 CONGRATULATIONS!  Your cluster is setup. 💥

You can get started with the UI for: nomad consul fabio here:

Nomad  (deployment: managements & scheduling):
( https://www.nomadproject.io )
$NOMAD_ADDR
( login with NOMAD_TOKEN from $HOME/.config/nomad - keep this safe!)

Consul (networking: service discovery & health checks, service mesh, envoy, secrets storage):
( https://www.consul.io )
$CONSUL_ADDR

Fabio  (routing: load balancing, ingress/edge router, https and http2 termination (to http))
( https://fabiolb.net )
$FABIO_ADDR



For localhost urls above - see 'nom-tunnel' alias here:
  https://gitlab.com/internetarchive/nomad/-/blob/master/aliases
"
}


function setup-consul() {
  ## Consul - setup xxxx ui = true ...
  echo '
server = true
advertise_addr = "{{ GetInterfaceIP \"eth0\" }}"
bootstrap_expect = 1
ui_config {
  enabled = true
}
' >> $CONSUL_HCL

  $SCTL restart consul  &&  sleep 10
}


function setup-nomad() {
  ## Nomad - setup

  # for persistent volumes
  mkdir -m777 -p /pv

  echo '
name = "'$(hostname -s)'"

server {
}

# some of this could be redundant -- check defaults in node v1+
addresses {
  http = "0.0.0.0"
}

advertise {
  http = "{{ GetInterfaceIP \"eth0\" }}"
  rpc = "{{ GetInterfaceIP \"eth0\" }}"
  serf = "{{ GetInterfaceIP \"eth0\" }}"
}

plugin "docker" {
  config {
    volumes {
      enabled = true
    }
  }
}

plugin "raw_exec" {
  config {
    enabled = true
  }
}

acl {
  enabled = true
}

client {
  meta {
    "kind" = "worker"
  }

  host_volume "pv" {
    path      = "/pv"
    read_only = false
  }

  host_volume "home-ro" {
    path      = "/home"
    read_only = true
  }

  host_volume "home-rw" {
    path      = "/home"
    read_only = false
  }
}' >> $NOMAD_HCL

  $SCTL restart nomad  &&  sleep 10
}


function nomad-env-vars() {
  mkdir -p $HOME/.config
  CONF=$HOME/.config/nomad

  local NOMACL=$HOME/.config/nomad.$(echo ${FIRST?} |cut -f1 -d.)
  mkdir -p $(dirname $NOMACL)
  chmod 600 $NOMACL $CONF 2>/dev/null |cat
  nomad acl bootstrap |tee $NOMACL
  # NOTE: can run `nomad acl token self` post-facto if needed...
  echo "
export NOMAD_ADDR=$NOMAD_ADDR
export NOMAD_TOKEN="$(fgrep 'Secret ID' $NOMACL |cut -f2- -d= |tr -d ' ') |tee $CONF
  chmod 400 $NOMACL $CONF

  source $CONF
}


function setup-daemons() {
  # get services ready to go
  echo "
[program:nomad]
command=/usr/bin/nomad  agent -config     /etc/nomad.d
autorestart=true
startsecs=10

[program:consul]
command=/usr/bin/consul agent -config-dir=/etc/consul.d/
autorestart=true
startsecs=10
" >| /etc/supervisor/conf.d/hind.conf
  supervisord
}


main "$@"
