provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      Project = "landing-zone"
    }
  }
}
resource "aws_resourcegroups_group" "landing_zone" {
  name = "rg-landing-zone"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "Project"
          Values = ["landing-zone"]
        }
      ]
    })
  }

  tags = {
    Name = "rg-landing-zone"
  }
}

### FASE 2 ### 

# Transit Gateway
resource "aws_ec2_transit_gateway" "tgw" {
  description                     = "Transit Gateway principal de la landing zone"
  amazon_side_asn                 = 64512 # Valor por defecto, reservado para uso futuro con VPN/Direct Connect
  auto_accept_shared_attachments  = "disable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"

  tags = {
    Name = "tgw"
  }
}

### FASE 3 ### 

# VPC Ingress
resource "aws_vpc" "ingress" {
  cidr_block = "10.1.0.0/16"

  tags = {
    Name = "vpc-ingress"
  }
}

# Internet Gateway 
resource "aws_internet_gateway" "ingress" {
  vpc_id = aws_vpc.ingress.id

  tags = {
    Name = "igw-ingress"
  }
}

# Subnets Públicas
resource "aws_subnet" "ingress_public_a" {
  vpc_id            = aws_vpc.ingress.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "subnet-ingress-public-a"
  }
}

resource "aws_subnet" "ingress_public_b" {
  vpc_id            = aws_vpc.ingress.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "subnet-ingress-public-b"
  }
}

# Subnets Privadas
resource "aws_subnet" "ingress_private_a" {
  vpc_id            = aws_vpc.ingress.id
  cidr_block        = "10.1.11.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "subnet-ingress-private-a"
  }
}

resource "aws_subnet" "ingress_private_b" {
  vpc_id            = aws_vpc.ingress.id
  cidr_block        = "10.1.12.0/24"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "subnet-ingress-private-b"
  }
}

# Route Table Ingress Public Subnet 
resource "aws_route_table" "ingress_public" {
  vpc_id = aws_vpc.ingress.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ingress.id
  }

  route {
    cidr_block = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }

  tags = {
    Name = "ingress-rt-public-subnet"
  }
}

resource "aws_route_table_association" "ingress_public_a" {
  subnet_id      = aws_subnet.ingress_public_a.id
  route_table_id = aws_route_table.ingress_public.id
}

resource "aws_route_table_association" "ingress_public_b" {
  subnet_id      = aws_subnet.ingress_public_b.id
  route_table_id = aws_route_table.ingress_public.id
}

# Route Table Ingress Private Subnet
resource "aws_route_table" "ingress_private" {
  vpc_id = aws_vpc.ingress.id

  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }

  tags = {
    Name = "ingress-rt-private-subnet"
  }
}

resource "aws_route_table_association" "ingress_private_a" {
  subnet_id      = aws_subnet.ingress_private_a.id
  route_table_id = aws_route_table.ingress_private.id
}

resource "aws_route_table_association" "ingress_private_b" {
  subnet_id      = aws_subnet.ingress_private_b.id
  route_table_id = aws_route_table.ingress_private.id
}

# TGW Attachment
resource "aws_ec2_transit_gateway_vpc_attachment" "ingress" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.ingress.id
  subnet_ids         = [
    aws_subnet.ingress_private_a.id,
    aws_subnet.ingress_private_b.id
  ]

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "attachment-ingress"
  }
}

# Application Load Balancer (ALB)
resource "aws_lb" "ingress" {
  name               = "alb-ingress"
  internal           = false
  load_balancer_type = "application"
  subnets            = [
    aws_subnet.ingress_public_a.id,
    aws_subnet.ingress_public_b.id
  ]
  security_groups    = [aws_security_group.alb_ingress.id]

  tags = {
    Name = "alb-ingress"
  }
}

# Security Group para el ALB
resource "aws_security_group" "alb_ingress" {
  name        = "alb-ingress-sg"
  description = "Security Group del ALB de Ingress"
  vpc_id      = aws_vpc.ingress.id

  ingress {
    from_port   = 443
    to_port     = 443
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
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  tags = {
    Name = "sg-alb-ingress"
  }
}

### VALIDACIÓN FASE 3 ###

# VPC Digital Channels
resource "aws_vpc" "digital_channels" {
  cidr_block = "10.110.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-digital-channels"
  }
}

# Subnets Privadas
resource "aws_subnet" "digital_channels_private_a" {
  vpc_id            = aws_vpc.digital_channels.id
  cidr_block        = "10.110.1.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "subnet-digital-channels-private-a"
  }
}

resource "aws_subnet" "digital_channels_private_b" {
  vpc_id            = aws_vpc.digital_channels.id
  cidr_block        = "10.110.2.0/24"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "subnet-digital-channels-private-b"
  }
}

# TGW Attachment Digital Channels
resource "aws_ec2_transit_gateway_vpc_attachment" "digital_channels" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.digital_channels.id
  subnet_ids         = [
    aws_subnet.digital_channels_private_a.id,
    aws_subnet.digital_channels_private_b.id
  ]

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "attachment-digital-channels"
  }
}

# TGW Route Table temporal
resource "aws_ec2_transit_gateway_route_table" "temp_validation" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id

  tags = {
    Name = "tgw-rt-temp-validation"
  }
}

# Rutas estáticas en la RT temporal
resource "aws_ec2_transit_gateway_route" "ingress_to_digital_channels" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.temp_validation.id
  destination_cidr_block         = "10.110.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.digital_channels.id
}

resource "aws_ec2_transit_gateway_route" "digital_channels_to_ingress" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.temp_validation.id
  destination_cidr_block         = "10.1.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.ingress.id
}

# Asociación de attachments a la RT temporal
resource "aws_ec2_transit_gateway_route_table_association" "ingress_temp" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.ingress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.temp_validation.id
}

resource "aws_ec2_transit_gateway_route_table_association" "digital_channels_temp" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.digital_channels.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.temp_validation.id
}

# Route Table para la subnet privada de Digital Channels
resource "aws_route_table" "digital_channels_private" {
  vpc_id = aws_vpc.digital_channels.id

  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }

  tags = {
    Name = "digital-channels-rt-private-subnet"
  }
}

resource "aws_route_table_association" "digital_channels_private_a" {
  subnet_id      = aws_subnet.digital_channels_private_a.id
  route_table_id = aws_route_table.digital_channels_private.id
}

resource "aws_route_table_association" "digital_channels_private_b" {
  subnet_id      = aws_subnet.digital_channels_private_b.id
  route_table_id = aws_route_table.digital_channels_private.id
}

# Security Group para la EC2
resource "aws_security_group" "ec2_digital_channels" {
  name        = "ec2-digital-channels-sg"
  description = "Security Group de la EC2 de Digital Channels"
  vpc_id      = aws_vpc.digital_channels.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = ["10.1.0.0/16"]
  }

   ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.110.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-ec2-digital-channels"
  }
}

# EC2 con Apache
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Target Group
resource "aws_lb_target_group" "digital_channels" {
  name        = "tg-digital-channels"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.ingress.id
  target_type = "ip"

  health_check {
    protocol            = "HTTP"
    port                = "80"
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
  }

  tags = {
    Name = "tg-digital-channels"
  }
}

# Listener en el ALB
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ingress.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.digital_channels.arn
  }

  tags = {
    Name = "listener-alb-ingress-http"
  }
}

resource "aws_lb_target_group_attachment" "ec2_digital_channels" {
  target_group_arn = aws_lb_target_group.digital_channels.arn
  target_id        = aws_instance.digital_channels.private_ip
  port             = 80
  availability_zone = "all"
}

# IAM Role para SSM
resource "aws_iam_role" "ec2_ssm" {
  name = "role-ec2-ssm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "role-ec2-ssm"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "profile-ec2-ssm"
  role = aws_iam_role.ec2_ssm.name

  tags = {
    Name = "profile-ec2-ssm"
  }
}

resource "aws_instance" "digital_channels" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.digital_channels_private_a.id
  vpc_security_group_ids = [aws_security_group.ec2_digital_channels.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name

  user_data = <<-EOF
  #!/bin/bash
  # v2
  yum update -y
  yum install -y httpd
  echo "<h1>Hola desde Digital Channels</h1>" > /var/www/html/index.html
  systemctl enable httpd
  systemctl start httpd
  sleep 5
  systemctl restart httpd
  EOF

  user_data_replace_on_change = true

  tags = {
    Name = "ec2-digital-channels"
  }
}

# VPC Endpoints para SSM
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.digital_channels.id
  service_name        = "com.amazonaws.eu-west-1.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.digital_channels_private_a.id]
  security_group_ids  = [aws_security_group.ec2_digital_channels.id]
  private_dns_enabled = true

  tags = {
    Name = "vpce-ssm"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.digital_channels.id
  service_name        = "com.amazonaws.eu-west-1.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.digital_channels_private_a.id]
  security_group_ids  = [aws_security_group.ec2_digital_channels.id]
  private_dns_enabled = true

  tags = {
    Name = "vpce-ssmmessages"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.digital_channels.id
  service_name        = "com.amazonaws.eu-west-1.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.digital_channels_private_a.id]
  security_group_ids  = [aws_security_group.ec2_digital_channels.id]
  private_dns_enabled = true

  tags = {
    Name = "vpce-ec2messages"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.digital_channels.id
  service_name      = "com.amazonaws.eu-west-1.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [aws_route_table.digital_channels_private.id]

  tags = {
    Name = "vpce-s3"
  }
}

