#!/bin/zsh -e

# Upgrades a cluster to latest:  nomad  consul  fabio

# Check these and upgrading version notes/warnings, linked in each, first:
#   https://www.nomadproject.io/docs/upgrade
#   https://www.consul.io/docs/upgrading

# Run this on each node in your cluster
# (NOTE: consul is <especially> recommended to be upgrade 1-node-at-a-time

# You should probably run these by hand on at least the first (if not all) nodes
# since `consul` got twitchy the 1st upgrade nov2021 and its cluster had no leader until
# repeated consul restarts, etc..

MYDIR=${0:a:h}



# upgrade nomad
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get -yqq update

apt-cache madison nomad |head -1

sudo apt-get -yqq install nomad

apt-cache madison nomad |head -1

sudo systemctl restart nomad




# upgrade consul
apt-cache madison consul |head -1

sudo apt-get -yqq install consul

apt-cache madison consul |head -1


sudo consul leave
sudo systemctl restart consul



# upgrade fabio
sudo docker pull fabiolb/fabio

nomad stop fabio
nomad run $MYDIR/etc/fabio.hcl
