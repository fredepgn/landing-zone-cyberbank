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
    cidr_block         = "10.0.0.0/8"
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

# Route Table para la subnet privada de Digital Channels
resource "aws_route_table" "digital_channels_private" {
  vpc_id = aws_vpc.digital_channels.id

  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }

   route {
    cidr_block         = "0.0.0.0/0"
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


  depends_on = [
    aws_vpc_endpoint.s3,
    aws_vpc_endpoint.ssm,
    aws_vpc_endpoint.ssmmessages,
    aws_vpc_endpoint.ec2messages
  ]

  user_data = <<-EOF
    #!/bin/bash
    for i in $(seq 1 10); do
      yum install -y httpd && break
      sleep 10
    done
    cat > /var/www/html/index.html << 'HTML'
    <!DOCTYPE html>
    <html lang="es">
    <head>
    <meta charset="utf-8">
    <title>CyberBank - Banca Digital</title>
    <style>
      body{margin:0;font-family:Arial,Helvetica,sans-serif;background:#f4f6f9;color:#0e2338}
      header{background:#ffffff;padding:16px 40px;display:flex;justify-content:space-between;align-items:center;box-shadow:0 1px 4px rgba(0,0,0,.08)}
      header img{height:52px}
      nav a{color:#0e2338;text-decoration:none;margin-left:22px;font-size:14px;font-weight:bold}
      .hero{background:linear-gradient(120deg,#0e2338,#3d7cb8);color:#fff;padding:70px 40px;text-align:center}
      .hero h2{font-size:34px;margin:0 0 12px}
      .hero p{font-size:16px;opacity:.9;margin:0 0 24px}
      .btn{background:#3d7cb8;color:#fff;border:none;padding:12px 28px;font-size:15px;font-weight:bold;border-radius:4px}
      .cards{display:flex;gap:20px;justify-content:center;padding:40px;flex-wrap:wrap}
      .card{background:#fff;border-radius:8px;padding:24px;width:230px;box-shadow:0 2px 8px rgba(0,0,0,.08)}
      .card h3{margin-top:0;color:#0e2338;font-size:17px}
      .card p{font-size:13px;color:#5a6b85}
      footer{text-align:center;padding:18px;font-size:12px;color:#8a97ab}
    </style>
    </head>
    <body>
    <header>
      <img src="data:image/png;base64,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" alt="CyberBank">
      <nav><a href="#">Cuentas</a><a href="#">Tarjetas</a><a href="#">Hipotecas</a><a href="#">Acceso clientes</a></nav>
    </header>
    <section class="hero">
      <h2>Tu banco, en cualquier lugar</h2>
      <p>Gestiona tus cuentas, tarjetas y ahorros desde la plataforma digital de CyberBank.</p>
      <button class="btn">Hazte cliente</button>
    </section>
    <section class="cards">
      <div class="card"><h3>Cuenta Online</h3><p>Sin comisiones y con transferencias inmediatas.</p></div>
      <div class="card"><h3>Tarjetas</h3><p>Debito y credito con control total desde la app.</p></div>
      <div class="card"><h3>Ahorro e inversion</h3><p>Planes flexibles adaptados a tus objetivos.</p></div>
    </section>
    <footer>CyberBank &copy; 2026 - Dominio Digital Channels</footer>
    </body>
    </html>
    HTML
    systemctl enable httpd
    systemctl start httpd
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

### FASE 4 ###

# VPC Egress
resource "aws_vpc" "egress" {
  cidr_block = "10.2.0.0/16"

  tags = {
    Name = "vpc-egress"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "egress" {
  vpc_id = aws_vpc.egress.id

  tags = {
    Name = "igw-egress"
  }
}

# Subnets Públicas
resource "aws_subnet" "egress_public_a" {
  vpc_id            = aws_vpc.egress.id
  cidr_block        = "10.2.1.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "subnet-egress-public-a"
  }
}

resource "aws_subnet" "egress_public_b" {
  vpc_id            = aws_vpc.egress.id
  cidr_block        = "10.2.2.0/24"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "subnet-egress-public-b"
  }
}

# Subnets Privadas
resource "aws_subnet" "egress_private_a" {
  vpc_id            = aws_vpc.egress.id
  cidr_block        = "10.2.11.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "subnet-egress-private-a"
  }
}

resource "aws_subnet" "egress_private_b" {
  vpc_id            = aws_vpc.egress.id
  cidr_block        = "10.2.12.0/24"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "subnet-egress-private-b"
  }
}

# Elastic IPs para los NAT Gateways
resource "aws_eip" "natgw_egress_a" {
  domain = "vpc"

  tags = {
    Name = "eip-natgw-egress-a"
  }
}

resource "aws_eip" "natgw_egress_b" {
  domain = "vpc"

  tags = {
    Name = "eip-natgw-egress-b"
  }
}

# NAT Gateways
resource "aws_nat_gateway" "egress_a" {
  allocation_id = aws_eip.natgw_egress_a.id
  subnet_id     = aws_subnet.egress_public_a.id

  tags = {
    Name = "natgw-egress-a"
  }
}

resource "aws_nat_gateway" "egress_b" {
  allocation_id = aws_eip.natgw_egress_b.id
  subnet_id     = aws_subnet.egress_public_b.id

  tags = {
    Name = "natgw-egress-b"
  }
}

# Route Table Pública
resource "aws_route_table" "egress_public" {
  vpc_id = aws_vpc.egress.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.egress.id
  }

  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }

  tags = {
    Name = "egress-rt-public-subnet"
  }
}

resource "aws_route_table_association" "egress_public_a" {
  subnet_id      = aws_subnet.egress_public_a.id
  route_table_id = aws_route_table.egress_public.id
}

resource "aws_route_table_association" "egress_public_b" {
  subnet_id      = aws_subnet.egress_public_b.id
  route_table_id = aws_route_table.egress_public.id
}

# Route Table Privada A
resource "aws_route_table" "egress_private_a" {
  vpc_id = aws_vpc.egress.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.egress_a.id
  }

  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }

  tags = {
    Name = "egress-rt-private-subnet-a"
  }
}

resource "aws_route_table_association" "egress_private_a" {
  subnet_id      = aws_subnet.egress_private_a.id
  route_table_id = aws_route_table.egress_private_a.id
}

# Route Table Privada B
resource "aws_route_table" "egress_private_b" {
  vpc_id = aws_vpc.egress.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.egress_b.id
  }

  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }

  tags = {
    Name = "egress-rt-private-subnet-b"
  }
}

resource "aws_route_table_association" "egress_private_b" {
  subnet_id      = aws_subnet.egress_private_b.id
  route_table_id = aws_route_table.egress_private_b.id
}

# TGW Attachment Egress
resource "aws_ec2_transit_gateway_vpc_attachment" "egress" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.egress.id
  subnet_ids         = [
    aws_subnet.egress_private_a.id,
    aws_subnet.egress_private_b.id
  ]

  appliance_mode_support                          = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "attachment-egress"
  }
}

### FASE 5 ### 

# VPC Inspection
resource "aws_vpc" "inspection" {
  cidr_block = "10.3.0.0/16"

  tags = {
    Name = "vpc-inspection"
  }
}

# Subnets TGW
resource "aws_subnet" "inspection_tgw_a" {
  vpc_id            = aws_vpc.inspection.id
  cidr_block        = "10.3.1.0/28"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "subnet-inspection-tgw-a"
  }
}

resource "aws_subnet" "inspection_tgw_b" {
  vpc_id            = aws_vpc.inspection.id
  cidr_block        = "10.3.2.0/28"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "subnet-inspection-tgw-b"
  }
}

# Subnets Firewall
resource "aws_subnet" "inspection_fw_a" {
  vpc_id            = aws_vpc.inspection.id
  cidr_block        = "10.3.11.0/28"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "subnet-inspection-fw-a"
  }
}

resource "aws_subnet" "inspection_fw_b" {
  vpc_id            = aws_vpc.inspection.id
  cidr_block        = "10.3.12.0/28"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "subnet-inspection-fw-b"
  }
}

# AWS Network Firewall Policy
resource "aws_networkfirewall_firewall_policy" "inspection" {
  name = "fw-policy-inspection"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.block_social_media.arn
    }

     stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.segmentation.arn
    }
  }

  tags = {
    Name = "fw-policy-inspection"
  }
}

# Grupo de reglas stateful - Bloqueo de redes sociales
resource "aws_networkfirewall_rule_group" "block_social_media" {
  capacity = 100
  name     = "rg-block-social-media"
  type     = "STATEFUL"

  rule_group {
    rule_variables {
      ip_sets {
        key = "HOME_NET"
        ip_set {
          definition = ["10.0.0.0/8"]
        }
      }
    }

   rules_source {
    rules_source_list {
      generated_rules_type = "DENYLIST"
      target_types         = ["HTTP_HOST", "TLS_SNI"]
      targets = [
        ".instagram.com",
        ".facebook.com",
        ".linkedin.com"
      ]
    }
  } 
  }

  tags = {
    Name = "rg-block-social-media"
  }
}

# AWS Network Firewall
resource "aws_networkfirewall_firewall" "inspection" {
  name                = "fw-inspection"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.inspection.arn
  vpc_id              = aws_vpc.inspection.id

  subnet_mapping {
    subnet_id = aws_subnet.inspection_fw_a.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.inspection_fw_b.id
  }

  tags = {
    Name = "fw-inspection"
  }
}

# TGW Attachment Inspection
resource "aws_ec2_transit_gateway_vpc_attachment" "inspection" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.inspection.id
  subnet_ids         = [
    aws_subnet.inspection_tgw_a.id,
    aws_subnet.inspection_tgw_b.id
  ]

  appliance_mode_support                          = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "attachment-inspection"
  }
}

# TGW Route Table Pre-Inspection
resource "aws_ec2_transit_gateway_route_table" "pre_inspection" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id

  tags = {
    Name = "tgw-rt-pre-inspection"
  }
}

# TGW Route Table Post-Inspection
resource "aws_ec2_transit_gateway_route_table" "post_inspection" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id

  tags = {
    Name = "tgw-rt-post-inspection"
  }
}

# Rutas en tgw-rt-pre-inspection
resource "aws_ec2_transit_gateway_route" "pre_inspection_default" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.pre_inspection.id
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.inspection.id
}

# Rutas en tgw-rt-post-inspection
resource "aws_ec2_transit_gateway_route" "post_inspection_ingress" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.post_inspection.id
  destination_cidr_block         = "10.1.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.ingress.id
}

resource "aws_ec2_transit_gateway_route" "post_inspection_egress" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.post_inspection.id
  destination_cidr_block         = "10.2.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
}

resource "aws_ec2_transit_gateway_route" "post_inspection_digital_channels" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.post_inspection.id
  destination_cidr_block         = "10.110.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.digital_channels.id
}

resource "aws_ec2_transit_gateway_route" "post_inspection_internet" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.post_inspection.id
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
}

# Asociaciones a tgw-rt-pre-inspection
resource "aws_ec2_transit_gateway_route_table_association" "ingress_pre" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.ingress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.pre_inspection.id
}

resource "aws_ec2_transit_gateway_route_table_association" "egress_pre" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.pre_inspection.id
}

resource "aws_ec2_transit_gateway_route_table_association" "digital_channels_pre" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.digital_channels.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.pre_inspection.id
}

# Asociación de Inspection a tgw-rt-post-inspection
resource "aws_ec2_transit_gateway_route_table_association" "inspection_post" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.inspection.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.post_inspection.id
}

# Route Tables dentro de la VPC de Inspection
# Locals para obtener los endpoints del firewall por AZ
locals {
  fw_endpoint_a = tolist([
    for i in aws_networkfirewall_firewall.inspection.firewall_status[0].sync_states :
    i.attachment[0].endpoint_id
    if i.availability_zone == "eu-west-1a"
  ])[0]

  fw_endpoint_b = tolist([
    for i in aws_networkfirewall_firewall.inspection.firewall_status[0].sync_states :
    i.attachment[0].endpoint_id
    if i.availability_zone == "eu-west-1b"
  ])[0]
}

# RT subnet TGW A
resource "aws_route_table" "inspection_tgw_a" {
  vpc_id = aws_vpc.inspection.id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = local.fw_endpoint_a
  }

  tags = {
    Name = "inspection-rt-tgw-a"
  }
}

resource "aws_route_table_association" "inspection_tgw_a" {
  subnet_id      = aws_subnet.inspection_tgw_a.id
  route_table_id = aws_route_table.inspection_tgw_a.id
}

# RT subnet TGW B
resource "aws_route_table" "inspection_tgw_b" {
  vpc_id = aws_vpc.inspection.id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = local.fw_endpoint_b
  }

  tags = {
    Name = "inspection-rt-tgw-b"
  }
}

resource "aws_route_table_association" "inspection_tgw_b" {
  subnet_id      = aws_subnet.inspection_tgw_b.id
  route_table_id = aws_route_table.inspection_tgw_b.id
}

# RT subnet Firewall A
resource "aws_route_table" "inspection_fw_a" {
  vpc_id = aws_vpc.inspection.id

  route {
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }

  tags = {
    Name = "inspection-rt-fw-a"
  }
}

resource "aws_route_table_association" "inspection_fw_a" {
  subnet_id      = aws_subnet.inspection_fw_a.id
  route_table_id = aws_route_table.inspection_fw_a.id
}

# RT subnet Firewall B
resource "aws_route_table" "inspection_fw_b" {
  vpc_id = aws_vpc.inspection.id

  route {
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }

  tags = {
    Name = "inspection-rt-fw-b"
  }
}

resource "aws_route_table_association" "inspection_fw_b" {
  subnet_id      = aws_subnet.inspection_fw_b.id
  route_table_id = aws_route_table.inspection_fw_b.id
}

### FASE 6 ###

# VPC Core Banking
resource "aws_vpc" "core_banking" {
  cidr_block           = "10.100.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-core-banking"
  }
}

# Subnets Privadas
resource "aws_subnet" "core_banking_private_a" {
  vpc_id            = aws_vpc.core_banking.id
  cidr_block        = "10.100.1.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "subnet-core-banking-private-a"
  }
}

resource "aws_subnet" "core_banking_private_b" {
  vpc_id            = aws_vpc.core_banking.id
  cidr_block        = "10.100.2.0/24"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "subnet-core-banking-private-b"
  }
}

# TGW Attachment Core Banking
resource "aws_ec2_transit_gateway_vpc_attachment" "core_banking" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.core_banking.id
  subnet_ids = [
    aws_subnet.core_banking_private_a.id,
    aws_subnet.core_banking_private_b.id
  ]

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "attachment-core-banking"
  }
}

# Route Table para la subnet privada de Core Banking
resource "aws_route_table" "core_banking_private" {
  vpc_id = aws_vpc.core_banking.id

  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }

  route {
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }

  tags = {
    Name = "core-banking-rt-private-subnet"
  }
}

resource "aws_route_table_association" "core_banking_private_a" {
  subnet_id      = aws_subnet.core_banking_private_a.id
  route_table_id = aws_route_table.core_banking_private.id
}

resource "aws_route_table_association" "core_banking_private_b" {
  subnet_id      = aws_subnet.core_banking_private_b.id
  route_table_id = aws_route_table.core_banking_private.id
}

# Security Group para la EC2
resource "aws_security_group" "ec2_core_banking" {
  name        = "ec2-core-banking-sg"
  description = "Security Group de la EC2 de Core Banking"
  vpc_id      = aws_vpc.core_banking.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.100.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-ec2-core-banking"
  }
}

# EC2 con Apache
resource "aws_instance" "core_banking" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.core_banking_private_a.id
  vpc_security_group_ids = [aws_security_group.ec2_core_banking.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name

   depends_on = [
    aws_vpc_endpoint.s3_core_banking,
    aws_vpc_endpoint.ssm_core_banking,
    aws_vpc_endpoint.ssmmessages_core_banking,
    aws_vpc_endpoint.ec2messages_core_banking
  ]

  user_data = <<-EOF
    #!/bin/bash
    for i in $(seq 1 10); do
      yum install -y httpd && break
      sleep 10
    done
    echo "<h1>Hola desde Core Banking</h1>" > /var/www/html/index.html
    systemctl enable httpd
    systemctl start httpd
  EOF

  user_data_replace_on_change = true

  tags = {
    Name = "ec2-core-banking"
  }
}

# VPC Endpoints para SSM
resource "aws_vpc_endpoint" "ssm_core_banking" {
  vpc_id              = aws_vpc.core_banking.id
  service_name        = "com.amazonaws.eu-west-1.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.core_banking_private_a.id]
  security_group_ids  = [aws_security_group.ec2_core_banking.id]
  private_dns_enabled = true

  tags = {
    Name = "vpce-ssm-core-banking"
  }
}

resource "aws_vpc_endpoint" "ssmmessages_core_banking" {
  vpc_id              = aws_vpc.core_banking.id
  service_name        = "com.amazonaws.eu-west-1.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.core_banking_private_a.id]
  security_group_ids  = [aws_security_group.ec2_core_banking.id]
  private_dns_enabled = true

  tags = {
    Name = "vpce-ssmmessages-core-banking"
  }
}

resource "aws_vpc_endpoint" "ec2messages_core_banking" {
  vpc_id              = aws_vpc.core_banking.id
  service_name        = "com.amazonaws.eu-west-1.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.core_banking_private_a.id]
  security_group_ids  = [aws_security_group.ec2_core_banking.id]
  private_dns_enabled = true

  tags = {
    Name = "vpce-ec2messages-core-banking"
  }
}

# VPC Endpoint para S3
resource "aws_vpc_endpoint" "s3_core_banking" {
  vpc_id            = aws_vpc.core_banking.id
  service_name      = "com.amazonaws.eu-west-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.core_banking_private.id]

  tags = {
    Name = "vpce-s3-core-banking"
  }
}

# VPC Corporate Services
resource "aws_vpc" "corporate_services" {
  cidr_block           = "10.120.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-corporate-services"
  }
}

# Subnets Privadas
resource "aws_subnet" "corporate_services_private_a" {
  vpc_id            = aws_vpc.corporate_services.id
  cidr_block        = "10.120.1.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "subnet-corporate-services-private-a"
  }
}

resource "aws_subnet" "corporate_services_private_b" {
  vpc_id            = aws_vpc.corporate_services.id
  cidr_block        = "10.120.2.0/24"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "subnet-corporate-services-private-b"
  }
}

# TGW Attachment Corporate Services
resource "aws_ec2_transit_gateway_vpc_attachment" "corporate_services" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.corporate_services.id
  subnet_ids = [
    aws_subnet.corporate_services_private_a.id,
    aws_subnet.corporate_services_private_b.id
  ]

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "attachment-corporate-services"
  }
}

# Route Table para la subnet privada de Corporate Services
resource "aws_route_table" "corporate_services_private" {
  vpc_id = aws_vpc.corporate_services.id

  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }

  route {
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }

  tags = {
    Name = "corporate-services-rt-private-subnet"
  }
}

resource "aws_route_table_association" "corporate_services_private_a" {
  subnet_id      = aws_subnet.corporate_services_private_a.id
  route_table_id = aws_route_table.corporate_services_private.id
}

resource "aws_route_table_association" "corporate_services_private_b" {
  subnet_id      = aws_subnet.corporate_services_private_b.id
  route_table_id = aws_route_table.corporate_services_private.id
}

# Security Group para la EC2
resource "aws_security_group" "ec2_corporate_services" {
  name        = "ec2-corporate-services-sg"
  description = "Security Group de la EC2 de Corporate Services"
  vpc_id      = aws_vpc.corporate_services.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.120.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-ec2-corporate-services"
  }
}

# EC2 con Apache
resource "aws_instance" "corporate_services" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.corporate_services_private_a.id
  vpc_security_group_ids = [aws_security_group.ec2_corporate_services.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm.name

  depends_on = [
    aws_vpc_endpoint.s3_corporate_services,
    aws_vpc_endpoint.ssm_corporate_services,
    aws_vpc_endpoint.ssmmessages_corporate_services,
    aws_vpc_endpoint.ec2messages_corporate_services
  ]

  user_data = <<-EOF
    #!/bin/bash
    for i in $(seq 1 10); do
      yum install -y httpd && break
      sleep 10
    done
    echo "<h1>Hola desde Corporate Services</h1>" > /var/www/html/index.html
    systemctl enable httpd
    systemctl start httpd
  EOF

  user_data_replace_on_change = true

  tags = {
    Name = "ec2-corporate-services"
  }
}

# VPC Endpoints para SSM
resource "aws_vpc_endpoint" "ssm_corporate_services" {
  vpc_id              = aws_vpc.corporate_services.id
  service_name        = "com.amazonaws.eu-west-1.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.corporate_services_private_a.id]
  security_group_ids  = [aws_security_group.ec2_corporate_services.id]
  private_dns_enabled = true

  tags = {
    Name = "vpce-ssm-corporate-services"
  }
}

resource "aws_vpc_endpoint" "ssmmessages_corporate_services" {
  vpc_id              = aws_vpc.corporate_services.id
  service_name        = "com.amazonaws.eu-west-1.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.corporate_services_private_a.id]
  security_group_ids  = [aws_security_group.ec2_corporate_services.id]
  private_dns_enabled = true

  tags = {
    Name = "vpce-ssmmessages-corporate-services"
  }
}

resource "aws_vpc_endpoint" "ec2messages_corporate_services" {
  vpc_id              = aws_vpc.corporate_services.id
  service_name        = "com.amazonaws.eu-west-1.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.corporate_services_private_a.id]
  security_group_ids  = [aws_security_group.ec2_corporate_services.id]
  private_dns_enabled = true

  tags = {
    Name = "vpce-ec2messages-corporate-services"
  }
}

# VPC Endpoint para S3
resource "aws_vpc_endpoint" "s3_corporate_services" {
  vpc_id            = aws_vpc.corporate_services.id
  service_name      = "com.amazonaws.eu-west-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.corporate_services_private.id]

  tags = {
    Name = "vpce-s3-corporate-services"
  }
}

# Asociación de Core Banking a tgw-rt-pre-inspection
resource "aws_ec2_transit_gateway_route_table_association" "core_banking_pre" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.core_banking.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.pre_inspection.id
}

# Asociación de Corporate Services a tgw-rt-pre-inspection
resource "aws_ec2_transit_gateway_route_table_association" "corporate_services_pre" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.corporate_services.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.pre_inspection.id
}

# Ruta hacia Core Banking en tgw-rt-post-inspection
resource "aws_ec2_transit_gateway_route" "post_inspection_core_banking" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.post_inspection.id
  destination_cidr_block         = "10.100.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.core_banking.id
}

# Ruta hacia Corporate Services en tgw-rt-post-inspection
resource "aws_ec2_transit_gateway_route" "post_inspection_corporate_services" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.post_inspection.id
  destination_cidr_block         = "10.120.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.corporate_services.id
}

# Grupo de reglas stateful - Segmentación de red entre dominios
resource "aws_networkfirewall_rule_group" "segmentation" {
  capacity = 100
  name     = "rg-segmentation"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      # Regla: permitir Corporate Services hacia Core Banking
      stateful_rule {
        action = "PASS"
        header {
          source           = "10.120.0.0/16"
          source_port      = "ANY"
          destination      = "10.100.0.0/16"
          destination_port = "ANY"
          protocol         = "IP"
          direction        = "FORWARD"
        }
        rule_option {
          keyword  = "sid"
          settings = ["100"]
        }
      }

      # Regla: denegar el resto de tráfico hacia Core Banking
      stateful_rule {
        action = "DROP"
        header {
          source           = "ANY"
          source_port      = "ANY"
          destination      = "10.100.0.0/16"
          destination_port = "ANY"
          protocol         = "IP"
          direction        = "FORWARD"
        }
        rule_option {
          keyword  = "sid"
          settings = ["101"]
        }
      }

      # Regla: denegar tráfico de Ingress hacia Corporate Services
      stateful_rule {
        action = "DROP"
        header {
          source           = "10.1.0.0/16"
          source_port      = "ANY"
          destination      = "10.120.0.0/16"
          destination_port = "ANY"
          protocol         = "IP"
          direction        = "FORWARD"
        }
        rule_option {
          keyword  = "sid"
          settings = ["102"]
        }
      }

      # Regla: permitir Core Banking hacia red interna del banco
      stateful_rule {
        action = "PASS"
        header {
          source           = "10.100.0.0/16"
          source_port      = "ANY"
          destination      = "10.0.0.0/8"
          destination_port = "ANY"
          protocol         = "IP"
          direction        = "FORWARD"
        }
        rule_option {
          keyword  = "sid"
          settings = ["103"]
        }
      }

      # Regla: denegar conexiones de Core Banking hacia Internet
      stateful_rule {
        action = "DROP"
        header {
          source           = "10.100.0.0/16"
          source_port      = "ANY"
          destination      = "ANY"
          destination_port = "ANY"
          protocol         = "IP"
          direction        = "FORWARD"
        }
        rule_option {
          keyword  = "sid"
          settings = ["104"]
        }
      }
    }
  }

  tags = {
    Name = "rg-segmentation"
  }
}
