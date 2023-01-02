#!/bin/zsh -eu

source /nomad/setup.env


LE_CRT=$LETSENCRYPT_DIR/$FQDN/$FQDN.crt
LE_KEY=$LETSENCRYPT_DIR/$FQDN/$FQDN.key

CRT=/opt/nomad/tls/tls.crt
KEY=/opt/nomad/tls/tls.key

sudo cp  $TLS_CRT  $CRT
sudo cp  $TLS_KEY  $KEY
sudo chown root.root   $CRT
sudo chown nomad.nomad $KEY  ||  echo nomad user gets created later
sudo chmod 444 $CRT
sudo chmod 400 $KEY
