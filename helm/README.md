# Helm Charts - Arquitectura de Microservicios en Azure

## 📋 Descripción General

Este repositorio contiene la configuración de **Helm Charts** para desplegar una arquitectura de microservicios en **Azure Kubernetes Service (AKS)**.

---

## 🏗️ Estructura del Proyecto

```
helm/
├── charts/
│   ├── backend/          # Plantillas K8s para el API
│   ├── frontend/         # Plantillas K8s para la Web
│   ├── gateway/          # Configuración del Ingress/FrontDoor
│   └── redis-client/     # Conexión al Azure Cache for Redis
└── environments/
    ├── region-a/
    │   ├── dev.yaml      # Réplicas mínimas, recursos limitados
    │   └── prod.yaml     # Alta disponibilidad
    └── region-b/
        ├── dev.yaml
        └── prod.yaml
```

---

## 🎯 Pilares de la Arquitectura

### 1. Estructura Estándar
Seguimos la especificación oficial de Helm Charts:
- `Chart.yaml` - Metadatos del chart
- `values.yaml` - Valores por defecto
- `templates/` - Plantillas de Kubernetes

### 2. Modularidad Multi-Chart
Cada servicio tiene su chart independiente:

| Chart | Responsabilidad |
|-------|-----------------|
| **backend** | API y lógica de negocio |
| **frontend** | Aplicación web |
| **gateway** | Ingress y enrutamiento |
| **redis-client** | Cache distribuido |

### 3. Preparación para Ambientes
Archivos de valores específicos por región y ambiente:

```bash
# Dev en región A
helm install my-app ./charts/backend -f environments/region-a/dev.yaml

# Prod en región B
helm install my-app ./charts/backend -f environments/region-b/prod.yaml
```

---

## 🚀 Uso Rápido

```bash
# Instalar
helm install my-backend ./charts/backend -f environments/region-a/dev.yaml

# Actualizar
helm upgrade my-backend ./charts/backend -f environments/region-a/prod.yaml

# Desinstalar
helm uninstall my-backend
```

---

**Última actualización:** Febrero 27, 2026
