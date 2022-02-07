job "fabio" {
  datacenters = ["dc1"]
  type        = "system"

  group "fabio" {
    task "fabio" {
      driver = "docker"

      config {
        image        = "fabiolb/fabio"
        network_mode = "host"
        volumes      = [ "/etc/fabio/:/etc/fabio/" ]

        args = [
          "-proxy.cs",
          "cs=my-certs;type=path;cert=/etc/fabio/ssl",
          "-proxy.addr",
          # "127.0.0.1:443;cs=my-certs;type=path;cert=/etc/fabio/ssl,127.0.0.1:80",
          "0.0.0.0:443;cs=my-certs;type=path;cert=/etc/fabio/ssl,0.0.0.0:80",
          "-proxy.header.sts.maxage",
          "15724800",
          "-proxy.header.sts.subdomains",
          "-proxy.header.clientip",
          "X-Forwarded-For",
        ]
      }

      resources {
        // "testing showed that while memory limits are enforced as one would expect,
        // "CPU limits are soft limits and not enforced as long as there is available CPU on the host machine."
        //   - https://blog.cloudflare.com/how-we-use-hashicorp-nomad/
        cpu    = 200
        memory = 128
      }
    }

    network {
      port "lb" {
        static = 443
      }

      port "http" {
        static = 80
      }

      port "ui" {
        static = 9998
      }
    }
  }
}
