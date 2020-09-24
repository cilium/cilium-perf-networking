
variable "packet_token" {
}

variable "packet_project_id" {
}

variable "packet_plan" {
    default = "c3.small.x86"
}

variable "packet_os" {
    default = "ubuntu_20_04"
}

variable "packet_location" {
    default = "ams1"
}

variable "node_ip0" {
  default = "10.33.33.10"
}

variable "node_ip1" {
  default = "10.33.33.11"
}

provider "packet" {
  auth_token = var.packet_token
}

# We need a VLAN for our L2 network
resource "packet_vlan" "knb" {
        description = "knb"
        facility    = var.packet_location
        project_id  = var.packet_project_id
}

resource "packet_device" "knb0" {
    hostname         = "knb-0"
    plan             = var.packet_plan
    facilities       = [ var.packet_location ]
    operating_system = var.packet_os
    billing_cycle    = "hourly"
    project_id       = var.packet_project_id

    connection {
           type = "ssh"
           host = packet_device.knb0.access_public_ipv4
           user = "root"
           agent = false
    }
}

resource "packet_device" "knb1" {
    hostname         = "knb-1"
    plan             = var.packet_plan
    facilities       = [ var.packet_location ]
    operating_system = var.packet_os
    billing_cycle    = "hourly"
    project_id       = var.packet_project_id

    connection {
           type = "ssh"
           host = packet_device.knb1.access_public_ipv4
           user = "root"
           agent = false
    }
}

# Set the devices to be in hybrid mode
resource "packet_device_network_type" "knb0" {
  device_id = packet_device.knb0.id
  type      = "hybrid"
}

resource "packet_device_network_type" "knb1" {
  device_id = packet_device.knb1.id
  type      = "hybrid"
}


resource "packet_port_vlan_attachment" "knb0" {
  device_id = packet_device_network_type.knb0.id
  port_name = "eth1"
  vlan_vnid = packet_vlan.knb.vxlan
}

resource "packet_port_vlan_attachment" "knb1" {
  device_id = packet_device_network_type.knb1.id
  port_name = "eth1"
  vlan_vnid = packet_vlan.knb.vxlan
}
