#!/bin/zsh -ex

# Creates a single node nomad cluster, running inside docker.
#
# Prerequisites:
# - you have a linux machine you can ssh to
# - VM/baremetal has `docker` installed

function main() {
  # starts up nomad, consul, etc.
  supervisord
  sleep 15

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


function nomad-env-vars() {
  mkdir -p $HOME/.config
  CONF=$HOME/.config/nomad

  local NOMACL=$HOME/.config/bootstrap.txt
  mkdir -p $(dirname $NOMACL)
  chmod 600 $NOMACL $CONF 2>/dev/null |cat
  nomad acl bootstrap |tee $NOMACL
  echo "
export NOMAD_ADDR=http://localhost:4646
export NOMAD_TOKEN="$(fgrep 'Secret ID' $NOMACL |cut -f2- -d= |tr -d ' ') |tee $CONF
  chmod 400 $NOMACL $CONF

  source $CONF
}


main
