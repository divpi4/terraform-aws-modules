#######################################
## VPC
#######################################

variable "create_vpc" {
  default = true
}

variable "azs" {
  default = []
}

variable "enable_dns_hostnames" {
  default = true
}

variable "enable_dns_support" {
  default = true
}

variable "cidr_block" {
  default = "192.168.0.0/16"
}

variable "instance_tenancy" {
  default = "default"
}

variable "enable_classic_link" {
  default = false
}

variable "enable_classic_link_dns_support" {
  default = false
}

variable "vpc_tags" {
  default = {}
}

#######################################
## VPC DHCP OPTIONS
#######################################

variable "create_dhcp_options" {
  default = false
}

variable "dhcp_domain_name" {
  default = ""
}

variable "dhcp_domain_name_servers" {
  default = []
}

variable "dhcp_ntp_servers" {
  default = []
}

variable "dhcp_netbios_name_servers" {
  default = []
}

variable "dhcp_netbios_node_type" {
  default = ""
}

variable "dhcp_option_tags" {
  default = {}
}

#######################################
## SUBNETS
#######################################

variable "pub_subnets" {
  default = []
}

variable "priv_subnets" {
  default = []
}

variable "map_public" {
  default = false
}

variable "pub_subnet_tags" {
  default = {}
}

variable "priv_subnet_tags" {
  default = {}
}

#######################################
## ROUTING AND INTERNET
#######################################

variable "create_nat_gw" {
  default = false
}

variable "num_nat_gws" {
  default = 0
}

variable "nat_gw_tags" {
  default = {}
}

variable "eip_tags" {
  default = {}
}

variable "inet_gw_tags" {
  default = {}
}

variable "pub_rt_tags" {
  default = {}
}

variable "priv_rt_tags" {
  default = {}
}

#######################################
## IPV6 ROUTING AND INTERNET
#######################################

variable "ipv6_on_create" {
  default = false
}

variable "create_ipv6_egress" {
  default = false
}

variable "ipv6_cidr_subnets" {
  default = []
}
