variable "aws_profile"    { type = "string" }
variable "aws_region"     { type = "string" }
variable "key_name"       { type = "string" }
variable "instance_type"  { type = "string" }
variable "root_size"      { type = "string" }

provider "aws" {
  region = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

resource "aws_vpc" "demo" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "demo" {
  vpc_id = "${aws_vpc.demo.id}"
}

resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.demo.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.demo.id}"
}

resource "aws_subnet" "demo" {
  vpc_id                  = "${aws_vpc.demo.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_security_group" "demo" {
  name        = "demo"
  vpc_id      = "${aws_vpc.demo.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "web" {
  connection {
    user = "ubuntu"
  }

  instance_type = "${var.instance_type}"
  ami = "${data.aws_ami.ubuntu.id}"
  key_name = "${var.key_name}"
  vpc_security_group_ids = ["${aws_security_group.demo.id}"]
  subnet_id = "${aws_subnet.demo.id}"
  associate_public_ip_address = "true"

  root_block_device = {
    volume_type = "gp2"
    volume_size = "${var.root_size}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get -y update",
      "sudo apt-get -y install nginx",
      "sudo service nginx start",
      "sudo useradd demo",
      "sudo hostnamectl set-hostname my-demo-host.local"
    ]
  }
}
