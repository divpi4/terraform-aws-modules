data "aws_availability_zones" "azs" {}

locals {
  pub_subnet_count  = "${var.create_vpc && length(var.pub_subnets) >= 1 ? length(var.pub_subnets) : 0}"
  priv_subnet_count = "${var.create_vpc && length(var.priv_subnets) >= 1 ? length(var.priv_subnets) : 0}"

  ### OUTPUTS
  dhcp_options_id             = "${var.create_dhcp_options ? aws_vpc_dhcp_options.this.id : ""}"
  dhcp_options_association_id = "${var.create_dhcp_options ? aws_vpc_dhcp_options_association.this.id : ""}"
}

#######################################
## VPC & OPTIONS
#######################################

resource "aws_vpc" "this" {
  count                            = "${var.create_vpc ? 1 : 0}"
  cidr_block                       = "${var.cidr_block}"
  instance_tenancy                 = "${var.instance_tenancy}"
  enable_dns_hostnames             = "${var.enable_dns_hostnames}"
  enable_dns_support               = "${var.enable_dns_support}"
  enable_classiclink               = "${var.enable_classic_link}"
  enable_classiclink_dns_support   = "${var.enable_classic_link_dns_support}"
  assign_generated_ipv6_cidr_block = true
  tags                             = "${var.vpc_tags}"
}

resource "aws_vpc_dhcp_options" "this" {
  count                = "${var.create_vpc && var.create_dhcp_options ? 1 : 0}"
  domain_name          = "${var.dhcp_domain_name}"
  domain_name_servers  = ["${var.dhcp_domain_name_servers}"]
  ntp_servers          = ["${var.dhcp_ntp_servers}"]
  netbios_name_servers = ["${var.dhcp_netbios_name_servers}"]
  netbios_node_type    = "${var.dhcp_netbios_node_type}"
  tags                 = "${var.dhcp_option_tags}"
}

resource "aws_vpc_dhcp_options_association" "this" {
  count           = "${var.create_vpc && var.create_dhcp_options ? 1 : 0}"
  vpc_id          = "${aws_vpc.this.id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.this.id}"
}

#######################################
## SUBNETS
#######################################

resource "aws_subnet" "public" {
  count                           = "${local.pub_subnet_count}"
  vpc_id                          = "${aws_vpc.this.id}"
  cidr_block                      = "${var.pub_subnets[count.index]}"
  availability_zone               = "${element(var.azs, count.index)}"
  map_public_ip_on_launch         = "${var.map_public}"
  assign_ipv6_address_on_creation = "${var.ipv6_on_create}"
  ipv6_cidr_block                 = "${cidrsubnet(aws_vpc.this.ipv6_cidr_block, 8, count.index)}"
  tags                            = "${var.pub_subnet_tags}"
}

resource "aws_subnet" "private" {
  count                           = "${local.priv_subnet_count}"
  vpc_id                          = "${aws_vpc.this.id}"
  cidr_block                      = "${var.priv_subnets[count.index]}"
  availability_zone               = "${element(var.azs, count.index)}"
  map_public_ip_on_launch         = false
  assign_ipv6_address_on_creation = "${var.ipv6_on_create}"
  ipv6_cidr_block                 = "${cidrsubnet(aws_vpc.this.ipv6_cidr_block, 8, 32+count.index)}"
  tags                            = "${var.priv_subnet_tags}"
}

#######################################
### ROUTING AND INTERNET
#######################################

### INTERNET GATEWAY
resource "aws_internet_gateway" "inet_gateway" {
  count  = "${length(var.pub_subnets) > 0 ? 1 : 0}"
  vpc_id = "${aws_vpc.this.id}"
  tags   = "${var.inet_gw_tags}"
}

resource "aws_egress_only_internet_gateway" "ipv6_gateway" {
  count  = "${var.create_ipv6_egress ? 1 : 0}"
  vpc_id = "${aws_vpc.this.id}"
}

### NAT GATEWAY and EIPS
resource "aws_eip" "natgw_ip" {
  count = "${var.create_nat_gw >= 1 && var.num_nat_gws >= 1 ? 1 : 0 }"
  vpc   = "true"
  tags  = "${var.eip_tags}"
}

resource "aws_nat_gateway" "nat_gw" {
  count         = "${var.create_nat_gw >= 1 && var.num_nat_gws >= 1 ? 1 : 0 }"
  allocation_id = "${aws_eip.natgw_ip.id}"
  subnet_id     = "${aws_subnet.public.*.id[count.index]}"
  tags          = "${var.nat_gw_tags}"
}

### ROUTE TABLES
resource "aws_route_table" "public" {
  count  = "${length(var.pub_subnets) >= 1 ? 1 : 0}"
  vpc_id = "${aws_vpc.this.id}"
  tags   = "${var.pub_rt_tags}"
}

resource "aws_route" "pub_default_v4" {
  count                  = "${length(var.pub_subnets) >= 1 ? 1 : 0}"
  route_table_id         = "${aws_route_table.public.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.inet_gateway.id}"
}

resource "aws_route" "pub_default_ipv6" {
  count                       = "${length(var.pub_subnets) > 0 ? 1 : 0}"
  route_table_id              = "${aws_route_table.public.id}"
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = "${aws_internet_gateway.inet_gateway.id}"
}

resource "aws_route_table_association" "public_association" {
  count          = "${length(var.pub_subnets) >= 1 ? length(var.pub_subnets) : 0}"
  subnet_id      = "${aws_subnet.public.*.id[count.index]}"
  route_table_id = "${aws_route_table.public.id}"
}

### PRIVATE TABLE
resource "aws_route_table" "private" {
  count  = "${length(var.priv_subnets) >= 1 ? 1 : 0}"
  vpc_id = "${aws_vpc.this.id}"
  tags   = "${var.priv_rt_tags}"
}

resource "aws_route" "priv_default_v4" {
  count                  = "${length(var.priv_subnets) >= 1 && var.create_nat_gw >= 1 && var.num_nat_gws >= 1 ? 1 : 0}"
  route_table_id         = "${aws_route_table.private.id}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${aws_nat_gateway.nat_gw.id}"
}

resource "aws_route" "priv_default_ipv6" {
  count                       = "${length(var.priv_subnets) > 0 && var.create_ipv6_egress > 0 ? 1 : 0}"
  route_table_id              = "${aws_route_table.private.id}"
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = "${aws_egress_only_internet_gateway.ipv6_gateway.id}"
}

resource "aws_route_table_association" "private_association" {
  count          = "${length(var.priv_subnets) >= 1 ? length(var.priv_subnets) : 0}"
  subnet_id      = "${aws_subnet.private.*.id[count.index]}"
  route_table_id = "${aws_route_table.private.id}"
}
