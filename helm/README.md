# 📂 Estructura de Helm - Arquitectura Geo-Replicada (Azure)

Este directorio contiene la configuración de **Helm** para el despliegue modular de microservicios en clústeres de **Azure Kubernetes Service (AKS)**, siguiendo el modelo de alta disponibilidad y recuperación ante desastres definido en el diagrama de arquitectura.

## 🏗️ Organización del Proyecto

La estructura sigue un patrón de **Umbrella Chart** para gestionar múltiples servicios de forma centralizada:

```text
project-root/
├── helm/
│   ├── charts/                # Sub-charts independientes
│   │   ├── frontend/          # Recursos de Frontend (Service, HPA)
│   │   ├── backend/           # Recursos de Backend (Service, HPA)
│   │   └── gateway/           # Configuración de Gateway (Pendiente)
│   ├── environments/          # Configuración por Región y Entorno
│   │   ├── region-a/          # Valores para Región 1 (ej. East US)
│   │   └── region-b/          # Valores para Región 2 (ej. West US)
│   ├── Chart.yaml             # Orquestador (Umbrella)
│   └── values.yaml            # Valores globales base
└── .github/workflows/         # Automatización de CI/CD (Lint & Dry-run)
