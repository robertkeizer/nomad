# syntax = docker/dockerfile:1.2
# https://docs.docker.com/develop/develop-images/build_enhancements/#overriding-default-frontends

FROM denoland/deno:alpine

# add `nomad` -- NOTE v1.2.3 breaks `nomad validate` where `CI_` env vars are loading into `project.hcl` ?!
RUN cd /usr/sbin && \
    wget -qO  nomad.zip  https://releases.hashicorp.com/nomad/1.2.3/nomad_1.2.3_linux_amd64.zip && \
    unzip     nomad.zip  && \
    rm        nomad.zip  && \
    chmod 777 nomad

# USER deno # xxxd

# NOTE: `nomad` binary needed for other repositories using us for CI/CD - but drop from _our_ webapp.
CMD rm /usr/sbin/nomad  &&  deno eval "import { serve } from 'https://deno.land/std/http/server.ts'; serve(() => new Response('hai'), { port: 5000 })"
