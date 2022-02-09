#!/bin/zsh -e

# starts up nomad, consul, etc.
( set -x; supervisord )
( set -x; sleep 15 )

echo "
export NOMAD_ADDR=http://localhost:4646
export NOMAD_TOKEN="$(nomad acl bootstrap |fgrep 'Secret ID' |cut -f2- -d= |tr -d ' ') \
    | tee $HOME/.nomad
chmod 400 $HOME/.nomad
source    $HOME/.nomad

echo "================================================================================"
( set -x; consul members )
echo "================================================================================"
( set -x; nomad server members )
echo "================================================================================"
( set -x; nomad node status )
echo "================================================================================"
