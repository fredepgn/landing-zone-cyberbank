# CyberBank | Landing Zone AWS con Terraform

Proyecto desarrollado como **Trabajo de Fin de Máster en Cybersecurity Management**. Consiste en el diseño e implementación progresiva, mediante Terraform, de una arquitectura de red **Hub & Spoke en AWS** para *CyberBank*, una entidad bancaria ficticia.

El proyecto se centra en la **segmentación y microsegmentación de red**, la separación de dominios y el control de los flujos de tráfico entre entornos mediante conectividad e inspección centralizadas.

## Arquitectura y alcance

El diseño incorpora los siguientes componentes:

- **Conectividad centralizada:** AWS Transit Gateway y tablas de rutas para interconectar las distintas VPC.
- **Ingress:** VPC de entrada con Application Load Balancer y un entorno *Digital Channels* utilizado para la validación de conectividad.
- **Egress:** VPC dedicada a la salida a Internet mediante NAT Gateways.
- **Inspection:** VPC de inspección con AWS Network Firewall y configuración de rutas para centralizar la inspección del tráfico de red.
- **Segmentación de dominios:** VPC de *Core Banking* y *Corporate Services*, con reglas de filtrado para controlar el tráfico entre los distintos segmentos de red.

## Estructura del repositorio

| Directorio | Contenido |
| --- | --- |
| `landing-zone-fase-2` | Creación del Transit Gateway. |
| `landing-zone-fase-3` | VPC de Ingress y validación de conectividad con Digital Channels. |
| `landing-zone-fase-4` | VPC de Egress y NAT Gateways. |
| `landing-zone-fase-5` | VPC de Inspection con AWS Network Firewall y reglas de filtrado del tráfico saliente por dominios. |
| `landing-zone-fase-6` | Incorporación de las VPC de Core Banking y Corporate Services, con reglas de segmentación y control de los flujos de tráfico entre dominios. |

Cada carpeta contiene una **versión acumulativa** del código Terraform hasta esa fase. Las carpetas permiten consultar la evolución del diseño; **no son módulos independientes que deban desplegarse conjuntamente**.

## Decisiones de diseño

La arquitectura separa la conectividad, la entrada y salida de tráfico y la inspección en componentes diferenciados. Las asociaciones y la propagación automática de rutas del Transit Gateway se deshabilitan para configurar explícitamente los recorridos de red.

Mediante AWS Network Firewall se implementan controles de filtrado del tráfico saliente basados en dominios HTTP y TLS, así como reglas *stateful* para definir los flujos de tráfico permitidos y bloqueados entre los distintos dominios de red.

## Contexto académico

Este repositorio contiene **el código de la infraestructura**, no la memoria completa del TFM. La memoria académica desarrolla la justificación del diseño, los diagramas de arquitectura y las validaciones realizadas.

El alcance se centra en **la arquitectura y seguridad de red**: no pretende representar una landing zone corporativa completa con todos los componentes de identidad, gobierno y cumplimiento, ni una configuración lista para producción.



