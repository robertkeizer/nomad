#!/bin/zsh -eu

# One time setup of server(s) to make a nomad cluster.

# xxx 2+ ip addresses for hostname to caddy LB https://caddy.community/t/caddy-as-clustered-load-balancer-hows-that-gonna-work/12510
#    could share certs dir over NFS or use Caddy API


echo '
# xxx wss dweb "in v2, you do not need to do anything to enable websockets."
dweb-webtorrent/.gitlab-ci.yml:  NOMAD_VAR_PORTS: { 7777 = "http", 6969 = "webtorrenttracker", 6881 = "webtorrentseeder" }
wss://wt.archive.org:6969

scribe-c2/.gitlab-ci.yml:  NOMAD_VAR_PORTS: { 9999 = "http" , -7777 = "tcp", 8889 = "reg" }


https://gitlab.com/internetarchive/nomad/-/blob/fabio/etc/fabio.properties
8989 http only (lcp)
7777 tcp (scribe-c2)(irc) (see `tcp` subdir)
(8200 tcp (testing only))

  "services-scribe-c2": [
    "urlprefix-services-scribe-c2.dev.archive.org"
  ],
  "services-scribe-c2-tcp": [
    "urlprefix-:7777 proto=tcp"
  ],


  "www-dweb": [
    "urlprefix-gateway.dweb.me",
    "urlprefix-dweb.me",
    "urlprefix-dweb.archive.org",
  ],
  "www-dweb-WOLK": [
    "urlprefix-dweb.archive.org:99/"
  ],


  "www-dwebcamp2022": [
    "urlprefix-www.dwebcamp.org",
    "urlprefix-dwebcamp.org",
    "urlprefix-www-dwebcamp2022.dev.archive.org",
    "urlprefix-dwebcamp.dev.archive.org",
  ],
  "www-dwebcamp2022-db": [
    "urlprefix-dwebcamp.org:5432/"
  ],


  "services-scribe-loki": [
    "urlprefix-services-scribe-loki.books-loki.archive.org",
  ],
  "services-scribe-loki-grafana": [
    "urlprefix-services-scribe-loki.books-loki.archive.org:3000/"
  ],
  "services-scribe-loki-prometheus": [
    "urlprefix-services-scribe-loki.books-loki.archive.org:9090/"
  ]
' > /dev/null

echo '
# TYPICAL
moo.code.archive.org {
	reverse_proxy 207.241.234.143:25496 {
		lb_policy least_conn
	}
}

# HTTPS alt port xxx
a.code.archive.org:8012 {
	reverse_proxy 207.241.234.143:25496 {
		lb_policy least_conn
	}
}

# HTTP alt port xxx
http://a.code.archive.org:8990 {
	reverse_proxy 207.241.234.143:25496 {
		lb_policy least_conn
	}
}

# HTTP (only) xxx
moo.code.archive.org:80 {
	reverse_proxy 207.241.234.143:25496 {
		lb_policy least_conn
	}
}

' > /dev/null


MYDIR=${0:a:h}
MYSELF=$MYDIR/setup.sh

# Our git repo
REPO=https://gitlab.com/internetarchive/nomad.git


function usage() {
  echo "
----------------------------------------------------------------------------------------------------
Usage: $MYSELF   <node 1>  <node 2>  ..

----------------------------------------------------------------------------------------------------
Make your first node be a FULLY-QUALIFIED DOMAIN NAME
  (and the one you'd like to use in urls if your machine has multiple names)

Run this script on a mac/linux laptop or VM where you can ssh in to all of your nodes.

We'll use lets encrypt generated certs that we'll create via \`caddy\`.
xxx: after 90 days you may need restart/reload nomad.

If invoking cmd-line has env var:
  NFSHOME=1                     -- then we'll setup /home/ r/o and r/w mounts
  NFS_PV=[IP ADDRESS:MOUNT_DIR] -- then we'll setup each VM with /pv mounting your NFS server for
                                   Persistent Volumes.  Example value: 1.1.1.1:/mnt/exports

----------------------------------------------------------------------------------------------------
Assumes you are creating cluster with debian/ubuntu VMs/baremetals,
that you have ssh and sudo access to.

Overview:
  Installs 'nomad'  server and client on all nodes, securely talking together & electing a leader
  Installs 'consul' server and client on all nodes
  Installs 'caddy' load balancer on all nodes
     (in case you want to use multiple IP addresses for deployments in case one LB/node is out)

----------------------------------------------------------------------------------------------------
NOTE: if setup 3 nodes (h0, h1 & h2) on day 1; and want to add 2 more (h3 & h4) later,
you should manually change 2 lines in \`setup-env-vars()\` in script -- look for INITIAL_CLUSTER_SIZE

"
  exit 1
}


function main() {
  # avoids any potentially previously set external environment vars from CLI poisoning..
  unset   NOMAD_TOKEN

  typeset -a NODES # array type env variable

  if [ "$1" = "setup-env-vars" ]; then
    setup-env-vars "$@"

  elif [ "$#" -gt 1 ]; then
    # This is where the script starts
    set -x

    # number of args from the command line are all the hostnames to setup
    NODES=( "$@" )

    for NODE in $NODES; do
      ssh $NODE "sudo apt-get -yqq install git  &&  sudo git clone $REPO /nomad;  cd /nomad  &&  sudo git pull"
    done

    # Setup certs & get consul up & running *first* -- so can use consul for nomad bootstraping.
    # Run setups across all VMs.
    # https://learn.hashicorp.com/tutorials/nomad/clustering#use-consul-to-automatically-cluster-nodes
    for NODE in $NODES; do
      # setup environment vars, then run installer
      ssh $NODE  /nomad/setup.sh  setup-env-vars  "$@"
      ssh $NODE  /nomad/setup.sh  setup-consul-caddy-misc
    done

    for NODE in $NODES; do
      ssh $NODE  /nomad/setup.sh  setup-certs
    done

    # Now get nomad configured and up - run "setup-nomad" on all VMs.
    for NODE in $NODES; do
      ssh $NODE  /nomad/setup.sh  setup-nomad
    done

    finish

  elif [ "$1" = "setup-consul-caddy-misc" ]; then
    setup-consul-caddy-misc

  elif [ "$1" = "setup-certs" ]; then
    setup-certs

  elif [ "$1" = "setup-nomad" ]; then
    setup-nomad

  else
    usage "$@"
  fi
}


function setup-env-vars() {
  # sets up environment variables into a tmp file and then sources it

  # number of args from the command line are all the hostnames to setup
  shift
  NODES=( "$@" )
  CLUSTER_SIZE=$#


  # This is normally 0, but if you later add nodes to an existing cluster, set this to
  # the number of nodes in the existing cluster.
  # Also manually set FIRST here to hostname of your existing cluster first VM.
  local INITIAL_CLUSTER_SIZE=0
  FIRST=$NODES[1]
  FIRST_FQDN=$NODES[1]

  # write all our needed environment variables to a file
  (
    # logical constants
    echo export CONSUL_ADDR="http://localhost:8500"
    echo export LETSENCRYPT_DIR="/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory"

    # Let's put caddy and consul on all servers
    echo export CADDY_COUNT=$CLUSTER_SIZE
    echo export CONSUL_COUNT=$CLUSTER_SIZE

    echo export NOMAD_ADDR="https://$FIRST_FQDN"

    echo export FIRST=$FIRST
    echo export FQDN=$(hostname -f)
    echo export NFSHOME=${NFSHOME:-""}
    echo export NFS_PV="${NFS_PV:-""}"
    echo export CLUSTER_SIZE=$CLUSTER_SIZE

    # this is normally 0, but if you later add nodes to an existing cluster, set this to
    # the number of nodes in the existing cluster.
    echo export INITIAL_CLUSTER_SIZE=$INITIAL_CLUSTER_SIZE

    # For each NODE to install on, set the COUNT or hostnumber from the order from the command line.
    COUNT=$INITIAL_CLUSTER_SIZE
    for NODE in $NODES; do
      echo export COUNT_$COUNT=$(echo $NODE | cut -f1 -d.)
      let "COUNT=$COUNT+1"
    done
  ) | sort | sudo tee /nomad/setup.env

  source /nomad/setup.env
}


function load-env-vars() {
  # avoid any potentially previously set external environment vars from CLI poisoning..
  unset   NOMAD_TOKEN
  unset   NOMAD_ADDR

  # loads environment variables that `setup-env-vars` previously setup
  source /nomad/setup.env

  # Now figure out what our COUNT number is for the host we are running on now.
  # Try short and FQDN hostnames since not sure what user ran on cmd-line.
  for HO in  $(hostname -s)  $(hostname); do
    export COUNT=$(env |egrep '^COUNT_'| fgrep "$HO" |cut -f1 -d= |cut -f2 -d_)
    [ -z "$COUNT" ]  ||  break
  done

  # the FIRST host *might* not be same as $(hostname) -- in that case we are 0
  [ -z "$COUNT" ]  &&  export COUNT=0

  set -x
}


function setup-consul-and-misc() {
  load-env-vars

  cd /tmp

  setup-misc
  setup-PV
  setup-consul
}


function setup-hashicorp() {
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
  ARCH=$(dpkg --print-architecture)
  sudo apt-add-repository "deb [arch=$ARCH] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
  sudo apt-get -yqq update
}

function setup-consul() {
  # sets up consul

  # install binaries and service files
  #   eg: /usr/bin/consul  /etc/consul.d/consul.hcl  /usr/lib/systemd/system/consul.service
  sudo apt-get -yqq install  consul

  # start up uncustomized version of consul
  sudo systemctl daemon-reload
  sudo systemctl enable  consul

  # find daemon config files from listing apt pkg contents ( eg: /etc/nomad.d/nomad.hcl )
  CONSUL_HCL=$(dpkg -L consul 2>/dev/null |egrep ^/etc/ |egrep -m1 '\.hcl$' || echo -n '')

  # restore original config (if reran)
  [ -e $CONSUL_HCL.orig ]  &&  sudo cp -p $CONSUL_HCL.orig $CONSUL_HCL

  # stash copies of original config
  sudo cp -p $CONSUL_HCL $CONSUL_HCL.orig


  # setup the fields 'encrypt' etc. as per your cluster.
  if [ $COUNT -eq 0 ]; then
    # starting cluster - how exciting!  mint some tokens
    TOK_C=$(consul keygen |tr -d ^)
  else
    # get the encrypt value from the first node's configured consul /etc/ file
    TOK_C=$(ssh $FIRST "egrep '^encrypt\s*=' $CONSUL_HCL" |cut -f2- -d= |tr -d '\t "')
  fi

  # get IP address of FIRST
  local FIRSTIP=$(host $FIRST | perl -ane 'print $F[3] if $F[2] eq "address"' |head -1)

  echo '
server = true
advertise_addr = "{{ GetInterfaceIP \"eth0\" }}"
node_name = "'$(hostname -s)'"
bootstrap_expect = '$CONSUL_COUNT'
encrypt = "'$TOK_C'"
retry_join = ["'$FIRSTIP'"]
' | sudo tee -a  $CONSUL_HCL

  # restart and give a few seconds to ensure server responds
  sudo systemctl restart consul  &&  sleep 10


  # avoid a decrypt bug (consul servers speak encrypted to each other over https)
  sudo rm -fv /opt/consul/serf/local.keyring
  # restart and give a few seconds to ensure server responds
  sudo systemctl restart  consul  &&  sleep 10


  set +x

  echo "================================================================================"
  ( set -x; consul members )
  echo "================================================================================"
}


function setup-nomad {
  # sets up nomad
  load-env-vars

  sudo apt-get -yqq install  nomad

  # find daemon config files from listing apt pkg contents ( eg: /etc/nomad.d/nomad.hcl )
  NOMAD_HCL=$( dpkg -L nomad  2>/dev/null |egrep ^/etc/ |egrep -m1 '\.hcl$' || echo -n '')


  [ -e  $NOMAD_HCL.orig ]  &&  sudo cp -p  $NOMAD_HCL.orig  $NOMAD_HCL
  sudo cp -p  $NOMAD_HCL  $NOMAD_HCL.orig

  sudo systemctl daemon-reload
  sudo systemctl enable  nomad


  # now that this user and group exist, lock certs dir down
  sudo chown -R nomad.nomad /opt/nomad/tls


  # setup the fields 'encrypt' etc. as per your cluster.
  [ $COUNT -eq 0 ]  &&  export TOK_N=$(nomad operator keygen |tr -d ^ |cat)
  # get the encrypt value from the first node's configured nomad /etc/ file
  [ $COUNT -ge 1 ]  &&  export TOK_N=$(ssh $FIRST "egrep  'encrypt\s*=' $NOMAD_HCL"  |cut -f2- -d= |tr -d '\t "' |cat)

  export HOME_NFS=/tmp/home
  mkdir -p $HOME_NFS
  [ $NFSHOME ]  &&  export HOME_NFS=/home


  # interpolate  nomad.hcl  to  $NOMAD_HCL
  ( echo "cat <<EOF"; cat /nomad/etc/nomad.hcl; echo EOF ) | sh | sudo tee $NOMAD_HCL


  # setup only 1st server to go into bootstrap mode (with itself)
  [ $COUNT -ge 1 ] && sudo sed -i -e 's^bootstrap_expect =.*$^^' $NOMAD_HCL


  # restart and give a few seconds to ensure server responds
  sudo systemctl restart nomad  &&  sleep 10

  # NOTE: if you see failures join-ing and messages like:
  #   "No installed keys could decrypt the message"
  # try either (depending on nomad or consul) inspecting all nodes' contents of file) and:
  # sudo rm /opt/nomad/data/server/serf.keyring
  # sudo systemctl restart  nomad
  set +x

  nomad-addr-and-token
  echo "================================================================================"
  ( set -x; nomad server members )
  echo "================================================================================"
  ( set -x; nomad node status )
  echo "================================================================================"
}


function nomad-addr-and-token() {
  # sets NOMAD_ADDR and NOMAD_TOKEN
  CONF=$HOME/.config/nomad
  if [ "$COUNT" = "0" ]; then
    # First VM -- bootstrap the entire nomad cluster
    # If you already have a .config/nomad file -- copy it to a `.prev` file.
    [ -e $CONF ]  &&  mv $CONF $CONF.prev
    # we only get one shot at bootstrapping the ACL info access to nomad -- so save entire response
    # to a separate file (that we can extract needed TOKEN from)
    local NOMACL=$HOME/.config/nomad.$FIRST
    mkdir -p $(dirname $NOMACL)
    chmod 600 $NOMACL $CONF 2>/dev/null |cat
    nomad acl bootstrap |tee $NOMACL
    # NOTE: can run `nomad acl token self` post-facto if needed...

    # extract TOKEN from $NOMACL; set it to NOMAD_TOKEN; place the 2 nomad access env vars into $CONF
    echo "
export NOMAD_ADDR=$NOMAD_ADDR
export NOMAD_TOKEN="$(fgrep 'Secret ID' $NOMACL |cut -f2- -d= |tr -d ' ') |tee $CONF
    chmod 400 $NOMACL $CONF
  fi
  source $CONF
}


function setup-consul-caddy-misc() {
  load-env-vars

  setup-hashicorp

  setup-consul-and-misc

  sudo apt-get -yqq install  consul-template  jq

  # https://caddyserver.com/docs/install#debian-ubuntu-raspbian
  sudo apt install -yqq debian-keyring debian-archive-keyring apt-transport-https
  [ -e /usr/share/keyrings/caddy-stable-archive-keyring.gpg ] ||
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
      |sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    |sudo tee /etc/apt/sources.list.d/caddy-stable.list
  sudo apt-get -yqq update
  sudo apt-get -yqq install caddy
  sudo mkdir -p    /var/lib/caddy
  sudo chown caddy /var/lib/caddy

  for i in  http.ctmpl  tcp.ctmpl  Caddyfile.ctmpl  Caddyfile.static  build.sh; do
    sudo ln -s /nomad/etc/caddy/$i /etc/caddy/$i
  done


  # get a compiled `caddy` binary that has plugin with additional raw TCP ability built-in
  sudo wget -qO  /usr/bin/caddy-plus-tcp  https://archive.org/download/nginx/caddy-plus-tcp
  sudo chmod +x  /usr/bin/caddy-plus-tcp

  (
    echo HOSTNAME=$FQDN
    echo TCP_DOMAIN=dev.archive.org # xxx
  ) |sudo tee /etc/caddy/env
}

function setup-certs() {
  # setup nomad w/ https certs so they can talk to each other, and we can talk to them securely.

  # now that consul is clustered and happy, we can customize `consul-template` and `caddy`
  sudo cp /nomad/etc/systemd/system/consul-template.service  /etc/systemd/system/


  sudo perl -i \
   -pe 's=bin/caddy([^-])=bin/caddy-plus-tcp$1=;' \
   -pe 's=/etc/caddy/Caddyfile([^\.])=/etc/caddy/Caddyfile.json$1=;' \
   /lib/systemd/system/caddy.service


  sudo systemctl daemon-reload
  sudo systemctl enable consul-template
  sudo systemctl status consul-template


  # wait for lets encrypt certs
  TLS_CRT=$LETSENCRYPT_DIR/$FQDN/$FQDN.crt
  TLS_KEY=$LETSENCRYPT_DIR/$FQDN/$FQDN.key

  wget -q --server-response http://$FQDN

  while true; do
    ( sudo cat $TLS_KEY |egrep . ) && break
    echo "waiting for $FQDN certs"
    sleep 1
  done
  sleep 2


  sudo mkdir -m 500 -p        /opt/nomad/tls
  sudo chmod -R go-rwx        /opt/nomad/tls
  /nomad/bin/nomad-tls.sh # xxx cron daily this
}

function setup-misc() {
  # sets up docker (if needed) and a few other misc. things
  sudo apt-get -yqq install  wget

  # install docker if not already present
  /nomad/bin/install-docker-ce.sh

  setup-ctop

  # avoid death by `odcker pull` timeout nomad kills relooping and destroying i/o throughput
  echo '{ "max-download-attempts": 1 }' >| sudo tee /etc/docker/daemon.json

  if [ -e /etc/ferm ]; then
    # archive.org uses `ferm` for port firewalling.
    # Open the minimum number of HTTP/TCP/UDP ports we need to run.
    /nomad/bin/ports-unblock.sh
    sudo service docker restart  ||  echo 'no docker yet'
  fi


  # This gets us DNS resolving on archive.org VMs, at the VM level (not inside containers)-8
  # for hostnames like:
  #   services-clusters.service.consul
  if [ -e /etc/dnsmasq.d/ ]; then
    echo "server=/consul/127.0.0.1#8600" |sudo tee /etc/dnsmasq.d/nomad
    # restart and give a few seconds to ensure server responds
    sudo systemctl restart dnsmasq
    sleep 2
  fi

  FI=/lib/systemd/system/systemd-networkd.socket
  if [ -e $FI ]; then
    # workaround focal-era bug after ~70 deploys (and thus 70 "veth" interfaces)
    # https://www.mail-archive.com/ubuntu-bugs@lists.ubuntu.com/msg5888501.html
    sudo sed -i -e 's^ReceiveBuffer=.*$^ReceiveBuffer=256M^' $FI
  fi


  # Need more (3GB) dirty byte limit for `docker pull` untar phase, else they can fail repeatedly.
  # IA Samuel only recomends on hosts w/ heavy fs metadata behavior + kernel 5.4 or newer for now.
  # You can verify the value via: `cat /proc/sys/vm/dirty_bytes`
  echo 'vm.dirty_bytes=3221225472' |sudo tee /etc/sysctl.d/90-vm-dirty_bytes.conf
}


function setup-PV() {
  sudo mkdir -m777 -p /pv

  if [ "$NFS_PV" ]; then
    sudo apt-get install -yqq nfs-common
    echo "$NFS_PV /pv nfs proto=tcp,nosuid,hard,intr,actimeo=1,nofail,noatime,nolock,tcp 0 0" |sudo tee -a /etc/fstab
    sudo mount /pv
  fi
}


function setup-ctop() {
  # really nice `ctop` - a container monitoring more specialized version of `top`
  # https://github.com/bcicen/ctop
  echo "deb http://packages.azlux.fr/debian/ buster main" | sudo tee /etc/apt/sources.list.d/azlux.list
  wget -qO - https://azlux.fr/repo.gpg.key | sudo apt-key add -
  sudo apt-get -yqq update
  sudo apt-get install -yqq docker-ctop
}


function finish() {
  set +x

  echo "

💥 CONGRATULATIONS!  Your cluster is setup. 💥

You can get started with the UI for: nomad & consul here:

Nomad  (deployment: managements & scheduling):
( https://www.nomadproject.io )
$NOMAD_ADDR
( login with NOMAD_TOKEN from $HOME/.config/nomad - keep this safe!)

Consul (networking: service discovery & health checks, service mesh, envoy, secrets storage):
( https://www.consul.io )
$CONSUL_ADDR

Caddy  (routing: load balancing, ingress router, https and http2 termination (to http))
( https://caddyserver.com/ )



For localhost urls above - see 'nom-tunnel' alias here:
  https://gitlab.com/internetarchive/nomad/-/blob/master/aliases

To uninstall:
  https://gitlab.com/internetarchive/nomad/-/blob/master/bin/wipe-node.sh


"
}


main "$@"
