---

## 1. Cambios en la Estructura del Repositorio Helm

### ¿Qué se cambió?

La estructura original tenía los subcharts anidados dentro de una carpeta `charts/` intermedia innecesaria. Por ejemplo:

```
# Antes
helm/frontend/charts/Chart.yaml
helm/frontend/charts/templates/

# Después
helm/frontend/Chart.yaml
helm/frontend/templates/
```

Adicionalmente, se eliminaron del control de versiones los archivos `.tgz` que estaban commiteados en `helm/charts/` y `helm/microservice/charts/`, y se agregaron al `.gitignore`.

También se identificaron y agregaron al `.gitignore` los archivos `.DS_Store` generados por macOS.

### ¿Por qué?

**Carpeta `charts/` intermedia:** Su presencia duplicaba innecesariamente la profundidad del árbol de directorios sin agregar valor. En Helm, la carpeta `charts/` tiene un significado reservado: es donde se almacenan las dependencias empaquetadas generadas por `helm dependency update`. Usarla como contenedor de la definición del chart genera confusión entre lo que es código fuente y lo que es un artefacto generado.

**Archivos `.tgz` commiteados:** Los `.tgz` son artefactos de build generados automáticamente por `helm dependency update` o `helm package`. Commitearlos al repositorio es equivalente a versionar un `.jar` o un `.exe` — aumenta el peso del repositorio, genera conflictos innecesarios en PRs y rompe el principio de que el repositorio debe contener solo código fuente, no artefactos derivados.

**Archivos `.DS_Store`:** Son metadatos internos de macOS sin ningún valor para el proyecto. Su presencia en el repositorio genera ruido en los diffs y puede exponer información sobre la estructura local de carpetas de los desarrolladores.

---

## 2. Creación del `values.yaml` Global

### ¿Qué se creó?

Se creó un `values.yaml` en la raíz del chart padre (`helm/values.yaml`) con dos responsabilidades:

```yaml
global:
  namespace: microservices

frontend:
  enabled: true
auth-api:
  enabled: true
# ... resto de subcharts
gateway-controller:
  enabled: false
```

### ¿Por qué?

**Valor global compartido (`global.namespace`):** Todos los subcharts referencian `{{ .Values.global.namespace }}` en sus templates. Sin un `values.yaml` raíz que lo defina, cada subchart debe declararlo de forma independiente, lo que genera duplicación y riesgo de inconsistencia si el namespace cambia. Helm propaga automáticamente los valores bajo `global` a todos los subcharts, lo que lo convierte en el lugar correcto para valores compartidos.

**Control de subcharts con `condition`:** La propiedad `condition` en cada dependencia del `Chart.yaml` permite habilitar o deshabilitar subcharts desde el `values.yaml` sin modificar el `Chart.yaml`. Esto es útil para escenarios donde no todos los servicios deben desplegarse en todos los entornos (por ejemplo, deshabilitar `gateway-controller` si aún no está listo), sin necesidad de comentar dependencias o mantener múltiples versiones del `Chart.yaml`.

---

## 3. Modificaciones en el Pipeline de CI (`helm-validate.yaml`)

### ¿Qué se cambió?

| Aspecto | Antes | Después |
| --- | --- | --- |
| Paths de los charts | `helm/charts/frontend`, `helm/charts/backend` (inexistentes) | Paths reales según el tree del repositorio |
| Lint | Solo frontend y backend | Lint individual por cada chart + lint del chart raíz |
| Dry Run | Tres dry-runs separados (microservicios, frontend, gateway) | Un único dry-run desde el chart raíz |
| Resolución de dependencias | No existía | `helm dependency update helm/` como paso previo |
| Charts faltantes | `routes` no se validaba | Se agrega lint de `routes` |

### ¿Por qué?

**`helm dependency update` como paso previo:** El chart raíz declara sus subcharts como dependencias en `Chart.yaml`. Sin ejecutar `helm dependency update` primero, Helm no puede resolver esas dependencias y tanto el lint como el dry-run fallan con un error de dependencias no resueltas. Este paso genera los `.tgz` en `helm/charts/` en tiempo de ejecución del pipeline, sin necesidad de commitearlos.

**Lint individual por subchart:** Hacer lint de cada chart por separado permite identificar con precisión cuál chart tiene un error, en lugar de obtener un error genérico del chart raíz que requiere investigación adicional para localizarlo.

**Lint del chart raíz:** Complementa el lint individual validando que la integración de todos los subcharts como un conjunto es coherente — por ejemplo, que los valores globales son consistentes entre charts.

**Un único Dry Run:** Dado que ahora existe un chart raíz que orquesta todos los subcharts, hacer dry-run desde `helm/` simula exactamente lo que ocurriría en un `helm install` real en producción. Mantener dry-runs separados por subchart duplica el trabajo y no refleja cómo se despliega realmente la aplicación.

---

## 4. Network Policies

### ¿Cómo se implementaron?

Se creó el archivo `helm/templates/networkpolicies.yaml` en el chart raíz, junto al `namespaces.yaml` existente. Se eligió este nivel porque las políticas aplican a namespaces completos, no a microservicios individuales, por lo que no tiene sentido que vivan dentro de un chart de aplicación.

El archivo `namespaces.yaml` existente fue modificado para agregar labels a cada namespace:

```yaml
metadata:
  name: microservices
  labels:
    name: microservices   # crítico para namespaceSelector
```

### Políticas implementadas y su significado

**Estrategia base — Deny All:**

```yaml
kind: NetworkPolicy
spec:
  podSelector: {}        # aplica a todos los pods del namespace
  policyTypes:
    - Ingress
    - Egress
```

Bloquea todo el tráfico de entrada y salida por defecto. Es el punto de partida obligatorio — sin esta política, todos los pods pueden comunicarse libremente entre sí y con el exterior. Se aplica a los tres namespaces: `microservices`, `frontend` y `gateway-infra`.

**Allow Internal (microservices):** Permite que los microservicios se comuniquen entre sí dentro del mismo namespace. Necesario porque servicios como `auth-api` llama a `users-api` directamente por DNS interno (`users-api-svc.microservices.svc.cluster.local`).

**Allow from Gateway (microservices):** Permite que el namespace `gateway-infra` envíe tráfico al namespace `microservices`. Sin esta política, el gateway no puede enrutar solicitudes a los microservicios a pesar de que el deny-all del gateway tenga egress habilitado hacia microservices — ambos extremos deben permitir el tráfico.

**Allow DNS Egress (microservices):** Permite tráfico de salida hacia el puerto 53 (UDP/TCP). Sin esta política, los pods no pueden resolver nombres DNS internos del clúster como `microservices-users-api-svc.microservices.svc.cluster.local`, lo que rompe toda comunicación entre servicios aunque el tráfico esté permitido por otras políticas.

**Allow Internal Egress (microservices):** Complementa el Allow Internal de ingress — permite que los pods del namespace `microservices` inicien conexiones hacia otros pods del mismo namespace. Ingress y Egress son independientes en Kubernetes; permitir uno no implica permitir el otro.

**Allow External Ingress (gateway-infra y frontend):** Permite tráfico entrante desde cualquier origen (`ingress: - {}`). El gateway y el frontend son los puntos de entrada públicos de la aplicación — deben aceptar tráfico del Load Balancer externo.

**Allow Egress to Microservices (gateway-infra):** Permite que el gateway envíe tráfico hacia el namespace `microservices`. Es la contrapartida del `allow-from-gateway` en el namespace de microservicios.

**Allow Egress to Gateway (frontend):** Permite que el frontend se comunique con `gateway-infra`. El frontend consume el API a través del gateway — sin esta política, el frontend quedaría aislado.

### ¿Se usó Calico?

**No.** Se utilizó el motor de Network Policies nativo de AKS (**Azure Network Policy Manager — Azure NPM**), que viene incluido con AKS cuando se usa Azure CNI. La razón es pragmática: Calico requiere ser habilitado explícitamente en el perfil de red del clúster al momento de su creación (`network_policy = "calico"` en Terraform), y el clúster actual no fue configurado con Calico desde el inicio.

La sintaxis de las Network Policies es **estándar de Kubernetes** en ambos casos — los mismos archivos YAML funcionan con Azure NPM o con Calico sin modificación. La diferencia entre ambos motores está en capacidades avanzadas que Calico ofrece adicionalmente (`GlobalNetworkPolicy`, egress por FQDN, políticas a nivel de nodo), las cuales no son necesarias para los requerimientos de esta HU. Calico puede incorporarse en una iteración futura habilitándolo en `tf-modules` sin necesidad de reescribir las políticas existentes.

---

## 5. Security Context

### ¿Cómo se implementó?

Se agregó la sección `securityContext` en dos niveles dentro del `deployment.yaml` de cada microservicio, parametrizada desde `values.yaml`:

```yaml
# En values.yaml de cada microservicio
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 2000
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
```

### Significado de cada directiva

**`runAsNonRoot: true` (nivel Pod):** Kubernetes rechaza el pod si la imagen intenta correr como usuario root (UID 0). Es la primera línea de defensa — si un atacante compromete el proceso dentro del contenedor, no tiene privilegios de root sobre el sistema de archivos del nodo.

**`runAsUser: 1000` (nivel Pod):** Fuerza al proceso principal del contenedor a correr con un UID específico no privilegiado. Evitar UID 0 (root) y UIDs del sistema (generalmente < 1000) reduce la superficie de ataque.

**`fsGroup: 2000` (nivel Pod):** Asigna un GID suplementario a todos los procesos del pod para acceso a volúmenes montados. Permite que el proceso acceda a archivos en volúmenes sin necesidad de ser root.

**`allowPrivilegeEscalation: false` (nivel Contenedor):** Impide que el proceso dentro del contenedor obtenga más privilegios de los que tiene al iniciar — bloquea llamadas a `setuid` y `setgid`. Previene que un proceso comprometido escale privilegios dentro del contenedor.

**`readOnlyRootFilesystem: true` (nivel Contenedor):** Monta el sistema de archivos raíz del contenedor en modo solo lectura. Previene que un atacante que comprometa el proceso pueda escribir archivos maliciosos, modificar binarios o instalar herramientas dentro del contenedor.

**`capabilities: drop: ALL` (nivel Contenedor):** Elimina todas las capabilities de Linux del proceso (como `NET_ADMIN`, `SYS_PTRACE`, `CHOWN`, etc.). Los contenedores heredan por defecto un conjunto de capabilities que no necesitan para funcionar — eliminarlas todas aplica el principio de mínimo privilegio a nivel de kernel.

### Consideraciones por runtime

| Servicio | Runtime | Consideración especial |
| --- | --- | --- |
| `auth-api` | Go | Sin restricciones adicionales — binario estático |
| `users-api` | Spring Boot (Java) | Requiere `emptyDir` en `/tmp` y `/app/tmp` — Spring Boot escribe temporales al arrancar |
| `todos-api` | Node.js | Requiere `emptyDir` en `/tmp` — Node.js escribe temporales en runtime |
| `log-message-processor` | Por confirmar | Verificar si escribe en disco |
| `redis` | Redis | `readOnlyRootFilesystem: false` — Redis necesita escritura en disco para persistencia (AOF/RDB). `runAsUser: 999` por convención del usuario `redis` |

Para `users-api` y `todos-api`, se agrega un volumen `emptyDir` que provee un espacio de escritura en memoria sin comprometer la restricción de filesystem de solo lectura:

```yaml
volumeMounts:
  - name: tmp
    mountPath: /tmp
volumes:
  - name: tmp
    emptyDir: {}
```

---
