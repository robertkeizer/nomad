server = true
advertise_addr = "{{ GetInterfaceIP \"eth0\" }}"
bootstrap_expect = 1

# xxxx consul ui fix
ui_config {
  enabled = true
}
