#!/bin/zsh -eu

source /nomad/setup.env


TLS_CRT=$LETSENCRYPT_DIR/$FQDN/$FQDN.crt
TLS_KEY=$LETSENCRYPT_DIR/$FQDN/$FQDN.key

cd /opt/nomad/tls

sudo cp  $TLS_CRT  tls.crt
sudo cp  $TLS_KEY  tls.key
sudo chown root.root   tls.crt
sudo chown nomad.nomad tls.key
sudo chmod 444 tls.crt
sudo chmod 400 tls.key
