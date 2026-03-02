# 📂 Estructura de Helm - Arquitectura Geo-Replicada (Azure)

Este directorio contiene la configuración de **Helm** para el despliegue modular de microservicios en clústeres de **Azure Kubernetes Service (AKS)**, siguiendo el modelo de alta disponibilidad y recuperación ante desastres definido en el diagrama de arquitectura.

## 🏗️ Metodología de Diseño: "Cloud-Agnostic Region"

Para cumplir con el requerimiento de Azure donde las regiones son asignadas dinámicamente (ej. `eastus`, `brazilsouth`), hemos aplicado una metodología de **Abstracción de Entorno**:

1.  **Independencia Regional:** Los Charts (`frontend`, `backend`) no contienen nombres de regiones "quemados" (hardcoded). Funcionan por inyección de valores.
2.  **Configuración via Overrides:** Toda la lógica de ubicación reside en la carpeta `environments/`. Si Azure asigna una nueva región, solo se debe actualizar el valor `global.region` en el YAML correspondiente.
3.  **Encapsulamiento:** Cada microservicio es un **Sub-chart**. Esto permite que el ciclo de vida del Frontend sea independiente del Backend, facilitando actualizaciones sin afectar la malla de servicios.

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
