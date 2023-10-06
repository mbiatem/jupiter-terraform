provider "aws" {
}

resource "aws_vpc" "dev-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    "Name" = "dev-vpc"
  }
}

resource "aws_internet_gateway" "dev-igw" {
    vpc_id = aws_vpc.dev-vpc.id
    tags = {
    "Name" = "dev-igw"
  }
}

resource "aws_subnet" "dev-public-subnet1" {
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1a"
  vpc_id = aws_vpc.dev-vpc.id
  map_public_ip_on_launch = true
  tags = {
    "Name" = "dev-public-subnet1"
  }
}

resource "aws_subnet" "dev-public-subnet2" {
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1b"
  vpc_id = aws_vpc.dev-vpc.id
  map_public_ip_on_launch = true
  tags = {
    "Name" = "dev-public-subnet2"
  }
}

resource "aws_subnet" "dev-private-subnet1" {
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  vpc_id = aws_vpc.dev-vpc.id
  tags = {
    "Name" = "dev-private-subnet1"
  }
}

resource "aws_subnet" "dev-private-subnet2" {
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1b"
  vpc_id = aws_vpc.dev-vpc.id
  tags = {
    "Name" = "dev-private-subnet2"
  }
}

resource "aws_eip" "dev-eip1" {
  tags = {
    "Name" = "dev-eip1"
  }
}

resource "aws_eip" "dev-eip2" {
  tags = {
    "Name" = "dev-eip2"
  }
}

resource "aws_nat_gateway" "dev-ngw1" {
  allocation_id = aws_eip.dev-eip1.id
  subnet_id = aws_subnet.dev-public-subnet1.id

  tags = {
    "Name" = "dev-ngw1"
  }
  depends_on = [ aws_internet_gateway.dev-igw ]
}

resource "aws_nat_gateway" "dev-ngw2" {
  allocation_id = aws_eip.dev-eip2.id
  subnet_id = aws_subnet.dev-public-subnet2.id

  tags = {
    "Name" = "dev-ngw2"
  }
  depends_on = [ aws_internet_gateway.dev-igw ]
}

resource "aws_route_table" "dev-public-rt" {
  vpc_id = aws_vpc.dev-vpc.id
  tags = {
    "Name" = "dev-public-rt"
  }
}

resource "aws_route" "public-internet-route" {
  route_table_id = aws_route_table.dev-public-rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.dev-igw.id
}

resource "aws_route_table_association" "public-rt-assoc1" {
  route_table_id = aws_route_table.dev-public-rt.id
  subnet_id = aws_subnet.dev-public-subnet1.id
}

resource "aws_route_table_association" "public-rt-assoc2" {
  route_table_id = aws_route_table.dev-public-rt.id
  subnet_id = aws_subnet.dev-public-subnet2.id
}

resource "aws_route_table" "dev-private-rt1" {
  vpc_id = aws_vpc.dev-vpc.id
  tags = {
    "Name" = "dev-private-rt1"
  }
}

resource "aws_route_table" "dev-private-rt2" {
  vpc_id = aws_vpc.dev-vpc.id
  tags = {
    "Name" = "dev-private-rt2"
  }
}

resource "aws_route" "private-internet-rt1" {
  route_table_id = aws_route_table.dev-private-rt1.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_nat_gateway.dev-ngw1.id
}

resource "aws_route" "private-internet-rt2" {
  route_table_id = aws_route_table.dev-private-rt2.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_nat_gateway.dev-ngw2.id
}

resource "aws_route_table_association" "private-rt-assoc1" {
  route_table_id = aws_route_table.dev-private-rt1.id
  subnet_id = aws_subnet.dev-private-subnet1.id
}

resource "aws_route_table_association" "private-rt-assoc2" {
  route_table_id = aws_route_table.dev-private-rt2.id
  subnet_id = aws_subnet.dev-private-subnet2.id
}

resource "aws_security_group" "alb-sg" {
  name_prefix = "alb-sg"
  description = "alb-sg"
  vpc_id = aws_vpc.dev-vpc.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "alb-sg"
  }

}

resource "aws_security_group" "webserver-sg" {
  name_prefix = "webserver-sg"
  description = "webserver-sg"
  vpc_id = aws_vpc.dev-vpc.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_groups = [aws_security_group.alb-sg.id]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    security_groups = [aws_security_group.alb-sg.id]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "webserver-sg"
  }
}

resource "aws_launch_template" "dev-app-lt" {
  name = "app-server-lt"
  image_id = "ami-090e0fc566929d98b"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.webserver-sg.id]
  tags = {
    "Name" = "app-server-lt"
  }

  description = "app-server-lt"

  user_data = base64encode(<<-EOF
    #!/bin/bash
    sudo su
    yum update -y
    yum install -y httpd
    cd /var/www/html
    wget https://github.com/elvis-cloud/jupiter/archive/refs/heads/main.zip
    unzip main.zip
    cp -r jupiter-main/* /var/www/html/
    rm -rf jupiter-main main.zip
    systemctl enable httpd 
    systemctl start httpd
    EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      "Name" = "app-server"
      "Environment" = "dev"
    }
  }
}

resource "aws_alb" "dev-alb" {
  name = "dev-alb"
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb-sg.id]
  subnets = [aws_subnet.dev-public-subnet1.id, aws_subnet.dev-public-subnet2.id]

  tags = {
    "Name" = "dev-alb" 
  }
}

resource "aws_alb_target_group" "dev-tg" {
  vpc_id = aws_vpc.dev-vpc.id
  name = "dev-lb-tg"
  port = 80
  protocol = "HTTP"
}

resource "aws_alb_listener" "dev-https-listener" {
  load_balancer_arn = aws_alb.dev-alb.arn
  port = "443"
  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-2016-08"
  certificate_arn = "arn:aws:acm:us-east-1:463570358144:certificate/9caa84a4-e44c-48ca-a43e-f751f4275c8d"

  default_action {
    type = "forward"

    target_group_arn = aws_alb_target_group.dev-tg.arn
  }
}

resource "aws_alb_listener" "dev-http-listener" {
  load_balancer_arn = aws_alb.dev-alb.arn
  port = "80"
  protocol = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_autoscaling_group" "dev-app-ASG" {
  name = "dev-app-ASG"
  launch_template {
    id = aws_launch_template.dev-app-lt.id
  }

  min_size = 2
  desired_capacity = 2
  max_size = 4
  vpc_zone_identifier = [aws_subnet.dev-private-subnet1.id, aws_subnet.dev-private-subnet2.id]
}

resource "aws_autoscaling_attachment" "dev-asg-alb-attachment" {
  autoscaling_group_name = aws_autoscaling_group.dev-app-ASG.id
  lb_target_group_arn = aws_alb_target_group.dev-tg.arn
}
