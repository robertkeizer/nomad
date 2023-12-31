#!/bin/zsh -eu

# Tries to ensure registry images running in the field are "backed" by their source registry.
# (eg: avoids problems w/ aggressive over-thinning of registries, if we want to move a deployment..)

for i in $(nomad node status |fgrep -v Eligibility |tr -s ' ' |cut -f1,3 -d' ' |tr ' ' '_' |sort); do
    id=$(echo $i|cut -f1 -d_)
  node=$(echo $i|cut -f2 -d_)
  for job in $(nomad node status -short $id |fgrep running |tr -s ' ' |cut -f 3 -d ' ' |sort); do
    echo $job
    IMG=$(nomad inspect $job |fgrep -m1 '"image":' |cut -f2- -d: |tr -d '", ' |tr -d ' ')

    echo $IMG

    [ "$IMG" = "" ] && continue
    ( echo $IMG | fgrep gitlab.com/    )  ||  continue
    ( echo $IMG | fgrep ghcr.io/       )  ||  continue

    set -x
    ssh $node sudo docker push $IMG  ||  echo FAIL $node $IMG
    set +x
  done
done
