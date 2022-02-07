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

  # start up uncustomized versions of nomad and consul
  setup-daemons

  # customize nomad & consul
  customize
}


function config() {
  export  NOMAD_ADDR="http://localhost:4646"
  export SCTL=supervisorctl

  # find daemon config files
   NOMAD_HCL=$(dpkg -L nomad  2>/dev/null |egrep ^/etc/ |egrep -m1 '\.hcl$' || echo -n '')
  CONSUL_HCL=$(dpkg -L consul 2>/dev/null |egrep ^/etc/ |egrep -m1 '\.hcl$' || echo -n '')
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

  local NOMACL=$HOME/.config/bootstrap.txt
  mkdir -p $(dirname $NOMACL)
  chmod 600 $NOMACL $CONF 2>/dev/null |cat
  nomad acl bootstrap |tee $NOMACL
  echo "
export NOMAD_ADDR=$NOMAD_ADDR
export NOMAD_TOKEN="$(fgrep 'Secret ID' $NOMACL |cut -f2- -d= |tr -d ' ') |tee $CONF
  chmod 400 $NOMACL $CONF

  source $CONF
}


function setup-daemons() {
  # get services ready to go
  mkdir -p -m755 /etc/fabio/ssl

  echo "
[program:nomad]
command=/usr/bin/nomad  agent -config     /etc/nomad.d
autorestart=true
startsecs=10

[program:consul]
command=/usr/bin/consul agent -config-dir=/etc/consul.d/
autorestart=true
startsecs=10

[program:fabio]
command=/bin/bash -c 'sleep 20; source /root/.config/nomad; nomad stop -purge fabio; sleep 10; nomad run /app/hind/fabio.hcl'
autorestart=false
" >| /etc/supervisor/conf.d/hind.conf
  supervisord
}


main "$@"
