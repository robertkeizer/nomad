#!/bin/zsh -eu

set -o allexport
source /etc/caddy/env
set +o allexport


LE_CRT=$LETSENCRYPT_DIR/$FQDN/$FQDN.crt
LE_KEY=$LETSENCRYPT_DIR/$FQDN/$FQDN.key

CRT=/opt/nomad/tls/tls.crt
KEY=/opt/nomad/tls/tls.key


function update-key() {
  echo "updating $KEY"
  sudo cp  $LE_CRT  $CRT
  sudo cp  $LE_KEY  $KEY
  sudo chown root.root   $CRT
  sudo chmod 444 $CRT
  sudo chmod 400 $KEY
}


# if $KEY doesnt exist, or $LE_KEY is newer than it, copy $KEY files
if ( sudo ls $KEY > /dev/null ); then
  sudo find $LE_KEY -cnewer $KEY -ls | egrep .  &&  update-key
else
  update-key
fi


sudo chown nomad.nomad $KEY  ||  echo nomad user gets created later
