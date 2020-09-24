output "ansible_inventory" {
    value = join("\n", [
            format("[master]\n%s ansible_python_interpreter=python3 ansible_user=root prv_ip=%s node_ip=%s master=knb-0\n",
            packet_device.knb0.access_public_ipv4,
            packet_device.knb0.access_private_ipv4,
            var.node_ip0,
        ),
            format("[nodes]\n%s ansible_python_interpreter=python3 ansible_user=root prv_ip=%s node_ip=%s\n",
            packet_device.knb1.access_public_ipv4,
            packet_device.knb1.access_private_ipv4,
            var.node_ip1,
        ),
    ])
}

output "ssh_config" {
    value = join("\n", [
					  format(""),
            format("Host knb-0\n\tHostname %s\n\tUser root", packet_device.knb0.access_public_ipv4),
            format("Host knb-1\n\tHostname %s\n\tUser root", packet_device.knb1.access_public_ipv4),
					  format("\n"),
					  format("ssh-keygen -f ~/.ssh/known_hosts -R %s", packet_device.knb0.access_public_ipv4),
					  format("ssh-keygen -f ~/.ssh/known_hosts -R %s", packet_device.knb1.access_public_ipv4)
    ])
}
