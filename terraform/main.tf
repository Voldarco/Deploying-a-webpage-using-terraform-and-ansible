
# Create VPC

resource "aws_vpc" "bill_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "bill_vpc"
  }
}


# Internet Gateway

resource "aws_internet_gateway" "bill_internet_gateway" {
  vpc_id = aws_vpc.bill_vpc.id
  tags ={
      Name = "bill_internet_gateway"
  }
}

# Create public Route Table

resource "aws_route_table" "bill-route-table-public" {
  vpc_id = aws_vpc.bill_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bill_internet_gateway.id
  }
  tags = {
    Name = "bill-route-table-public"
  }
}

# Associate public subnet 1 with public route table { i see billing}

resource "aws_route_table_association" "bill-public-subnet1-association" {
  subnet_id      = aws_subnet.bill-public-subnet1.id
  route_table_id = aws_route_table.bill-route-table-public.id
}

# Associate public subnet 2 with public route table { billing maximized}

resource "aws_route_table_association" "bill-public-subnet2-association" {
  subnet_id      = aws_subnet.bill-public-subnet2.id
  route_table_id = aws_route_table.bill-route-table-public.id
}

# Create Public Subnet-1

resource "aws_subnet" "bill-public-subnet1" {
  vpc_id                  = aws_vpc.bill_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "bill-public-subnet1"
  }
}


# Create Public Subnet-2

resource "aws_subnet" "bill-public-subnet2" {
  vpc_id                  = aws_vpc.bill_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
  tags = {
    Name = "bill-public-subnet2"
  }
}

resource "aws_network_acl" "bill-network_acl" {
  vpc_id     = aws_vpc.bill_vpc.id
  subnet_ids = [aws_subnet.bill-public-subnet1.id, aws_subnet.bill-public-subnet2.id]
 
  ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
}

# Create a security group for the load balancer {i actually love this part. }

resource "aws_security_group" "bill-load_balancer_sg" {
  name        = "bill-load-balancer-sg"
  description = "Security group for the load balancer"
  vpc_id      = aws_vpc.bill_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
   
  }
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Security Group to allow port 22, 80 and 443
resource "aws_security_group" "bill-security-grp-rule" {
  name        = "allow-ssh-http-https"
  description = "Allow SSH, HTTP and HTTPS inbound traffic."
  vpc_id      = aws_vpc.bill_vpc.id
 ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.bill-load_balancer_sg.id]
  }
 ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.bill-load_balancer_sg.id]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
   
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
   
  }
  tags = {
    Name = "bill-security-grp-rule"
  }
}

# creating server-instance 1 { The boss of bills arrives}

resource "aws_instance" "server1" {
  ami             = "ami-00874d747dde814fa"
  instance_type   = "t2.micro"
  key_name        = "Ubuntu"
  security_groups = [aws_security_group.bill-security-grp-rule.id]
  subnet_id       = aws_subnet.bill-public-subnet1.id
  availability_zone = "us-east-1a"
  tags = {
    Name   = "server-1"
    source = "terraform"
  }
}
# creating server-instance 2
 resource "aws_instance" "server2" {
  ami             = "ami-00874d747dde814fa"
  instance_type   = "t2.micro"
  key_name        = "Ubuntu"
  security_groups = [aws_security_group.bill-security-grp-rule.id]
  subnet_id       = aws_subnet.bill-public-subnet2.id
  availability_zone = "us-east-1b"
  tags = {
    Name   = "server-2"
    source = "terraform"
  }
}
# creating instance 3
resource "aws_instance" "server3" {
  ami             = "ami-00874d747dde814fa"
  instance_type   = "t2.micro"
  key_name        = "Ubuntu"
  security_groups = [aws_security_group.bill-security-grp-rule.id]
  subnet_id       = aws_subnet.bill-public-subnet1.id
  availability_zone = "us-east-1a"
  tags = {
    Name   = "server-3"
    source = "terraform"
  }
}

# Create a file to store the IP addresses of the instances

resource "local_file" "Ip_address" {
  filename = "/home/ubuntu/Deploying-a-webpage-using-terraform-and-ansible/Ansible/inventory"
  content  = <<EOT
${aws_instance.server1.public_ip}
${aws_instance.server2.public_ip}
${aws_instance.server3.public_ip}
  EOT
}

# Create Application Load Balancer

resource "aws_lb" "bill-load-balancer" {
  name               = "bill-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.bill-load_balancer_sg.id]
  subnets            = [aws_subnet.bill-public-subnet1.id, aws_subnet.bill-public-subnet2.id]
  #enable_cross_zone_load_balancing = true
  enable_deletion_protection = false
  depends_on                 = [aws_instance.server1, aws_instance.server2, aws_instance.server3]
}

# Create the target group

resource "aws_lb_target_group" "bill-target-group" {
  name     = "bill-target-group"
  target_type = "instance"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.bill_vpc.id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# Create the listener

resource "aws_lb_listener" "bill-listener" {
  load_balancer_arn = aws_lb.bill-load-balancer.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bill-target-group.arn
  }
}

# Create the listener rule

resource "aws_lb_listener_rule" "bill-listener-rule" {
  listener_arn = aws_lb_listener.bill-listener.arn
  priority     = 1
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bill-target-group.arn
  }
  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

# Attach the target group to the load balancer

resource "aws_lb_target_group_attachment" "bill-target-group-attachment1" {
  target_group_arn = aws_lb_target_group.bill-target-group.arn
  target_id        = aws_instance.server1.id
  port             = 80
}
 
resource "aws_lb_target_group_attachment" "bill-target-group-attachment2" {
  target_group_arn = aws_lb_target_group.bill-target-group.arn
  target_id        = aws_instance.server2.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "bill-target-group-attachment3" {
  target_group_arn = aws_lb_target_group.bill-target-group.arn
  target_id        = aws_instance.server3.id
  port             = 80
 
  }

