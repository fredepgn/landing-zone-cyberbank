# TFM Landing Zone CyberBank - Código Terraform

Código Terraform del despliegue de una landing zone con arquitectura Hub & Spoke en AWS 
para el banco ficticio CyberBank, desarrollado como Trabajo Fin de Máster.

## Estructura

- `landing-zone-fase-2/` — Transit Gateway
- `landing-zone-fase-3/` — VPC de Ingress + validación con Digital Channels
- `landing-zone-fase-4/` — VPC de Egress (NAT Gateways)
- `landing-zone-fase-5/` — VPC de Inspection (AWS Network Firewall)
- `landing-zone-fase-6/` — Spokes Core Banking y Corporate Services + segmentación de red

Cada carpeta contiene el código Terraform correspondiente a esa fase, 
acumulativo respecto a las fases anteriores.
