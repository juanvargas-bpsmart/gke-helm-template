# Helm Template (Plantilla Centralizada para Microservicios)

Este repositorio contiene la **plantilla maestra de Helm (Common Chart)** utilizada para estandarizar y simplificar el despliegue de todos los microservicios de la organización en Google Kubernetes Engine (GKE).

Al centralizar las plantillas de Kubernetes aquí, evitamos que cada microservicio tenga que mantener y duplicar su propia carpeta de Helm. Los servicios individuales solo se encargan de almacenar su código y sus archivos de configuración de entorno (`values.yaml`).

---

## Estructura del Repositorio

*   **`chart/`**: Contiene la definición del Helm Chart centralizado.
    *   **`templates/deployment.yaml`**: Plantilla para el Deployment de Kubernetes (incluye configuración de réplicas, puertos, sondas de salud y lógica de volúmenes condicionales).
    *   **`templates/service.yaml`**: Plantilla para exponer los puertos de la aplicación hacia el clúster.
    *   **`templates/pvc.yaml`**: Plantilla condicional para reclamar almacenamiento persistente (ej. almacenamiento para sesiones de WhatsApp).
    *   **`Chart.yaml`**: Metadatos del chart maestro.
    *   **`values.yaml`**: Valores por defecto (fallback) para evitar errores si un microservicio no define alguna variable obligatoria.

---

##  ¿Cómo funciona el ciclo de vida de la plantilla?

El flujo de trabajo sigue de forma estricta el patrón de GitOps centralizado:

1.  **Cambios en el Template**: Cada vez que se realiza un ajuste en las plantillas de Kubernetes de este repositorio y se hace un `merge` a la rama `main`, se dispara un pipeline de GitHub Actions.
2.  **Empaquetado y Versión**: El pipeline empaqueta el chart y le asigna una versión única.
3.  **Publicación (Push OCI)**: El chart empaquetado se sube como un artefacto OCI directamente a nuestro **GCP Artifact Registry**.

---

## 🛠️ ¿Cómo consumen los microservicios esta plantilla?

Los repositorios de los microservicios ya no tienen archivos `.yaml` de Kubernetes. En su lugar, durante su propio pipeline de despliegue, realizan los siguientes pasos:

1.  Generan su imagen Docker y la suben a Artifact Registry.
2.  Generan su archivo de configuración interpolando variables de entorno con `envsubst` (ej: `values-dev.yaml`).
3.  Se conectan de forma segura a través del **Bastion Host (IAP)** y ejecutan la instalación jalando este chart central directamente desde la ruta OCI de Artifact Registry:

```bash
helm upgrade --install nombre-del-servicio \
  oci://<REGION>-docker.pkg.dev/<PROJECT_ID>/helm-general-template/helm-general-template \
  -f ~/nombre-del-servicio/values.yaml \
  --version 1.0.0 \
  --namespace <GCP_ENV> \
  --wait --timeout 300s \
  --atomic
```

---

## Ejemplo de Configuración en el Microservicio (`values.yaml`)

Para desplegar un microservicio utilizando esta plantilla, el repositorio de la aplicación solo necesita definir un archivo de valores que mapee los campos del template central. Ejemplo:

```yaml
config:
  replicas: 1
  name: mi-servicio
  image: us-central1-docker.pkg.dev/proyecto/mi-servicio:commit-sha
  nodePool: pool-aplicaciones
  namespace: dev
  serviceAccount: k8s-dev
  resources:
    requests:
      memory: 2Gi
      cpu: 350m
    limits:
      memory: 3Gi
      cpu: 900m

variables:
  - name: PORT
    value: "8080"
  - name: NODE_ENV
    value: "development"

# Si el servicio no necesita persistencia, cambiar a 'enabled: false'
persistence:
  enabled: true
  name: wsp-sessions
  size: 10Gi
  storageClass: standard-rwo
  mountPath: /app/.wwebjs_auth
```