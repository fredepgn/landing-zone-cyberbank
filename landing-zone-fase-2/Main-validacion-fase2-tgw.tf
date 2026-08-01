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

