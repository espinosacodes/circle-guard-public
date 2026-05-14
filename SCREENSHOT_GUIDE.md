# Screenshot Guide — Taller 2

El reporte exige **pantallazos de la configuración** y **pantallazos de la ejecución exitosa** de cada pipeline. Esta guía contiene los comandos exactos a ejecutar y qué capturar.

Atajo de macOS para captura selectiva: **Cmd + Shift + 4** (arrastra el área).
Atajo para ventana específica: **Cmd + Shift + 4** y luego **Space**.

Guarda todas las capturas en `screenshots/` (crea la carpeta si no existe):

```bash
mkdir -p screenshots
```

---

## A. Capturas de Configuración

### A.1 Pods corriendo en dev

```bash
kubectl get pods -n circleguard-dev
```

**Capturar:** terminal con los 13 pods en `Running 1/1`.
Guardar como `screenshots/01-k8s-dev-pods.png`.

*Nota:* `docker compose ps` no mostrará nada porque los servicios corren como pods de K8s, no como contenedores de Docker Compose. Usa siempre `kubectl get pods -n <namespace>`.

### A.2 Dockerfile de un servicio (ejemplo: auth-service)

Abrir en VS Code:
```bash
code services/circleguard-auth-service/Dockerfile
```

**Capturar:** el editor mostrando el contenido completo (10 líneas).
Guardar como `screenshots/02-dockerfile.png`.

### A.3 Kubernetes manifiestos

```bash
ls -la k8s/dev/ k8s/stage/ k8s/master/
```

**Capturar:** terminal mostrando los 3 archivos (`namespace.yml`, `infrastructure.yml`, `services.yml`) en cada uno.
Guardar como `screenshots/03-k8s-structure.png`.

Adicional, abrir uno en VS Code para mostrar contenido:
```bash
code k8s/dev/services.yml
```

**Capturar:** las primeras 60 líneas (ConfigMap + Auth Deployment).
Guardar como `screenshots/04-k8s-services-yml.png`.

### A.4 Jenkins desplegado

Si Jenkins está corriendo (opcional):
```bash
cd jenkins && docker-compose up -d
open http://localhost:8090
```

**Capturar:** dashboard de Jenkins (puede estar vacío).
Guardar como `screenshots/05-jenkins-dashboard.png`.

### A.5 Jenkinsfile.dev

```bash
code Jenkinsfile.dev
```

**Capturar:** scrolleando por las stages.
Guardar como `screenshots/06-jenkinsfile-dev.png`.

### A.6 Jenkinsfile.stage

```bash
code Jenkinsfile.stage
```

**Capturar:** las stages 1-11.
Guardar como `screenshots/07-jenkinsfile-stage.png`.

### A.7 Jenkinsfile.master

```bash
code Jenkinsfile.master
```

**Capturar:** las stages incluyendo "Generate Release Notes" y "Approval Gate".
Guardar como `screenshots/08-jenkinsfile-master.png`.

### A.8 Tests directory tree

```bash
tree tests/ -L 3 2>/dev/null || find tests/ -maxdepth 3 -type f
```

**Capturar:** estructura completa.
Guardar como `screenshots/09-tests-structure.png`.

### A.9 Locustfile

```bash
code tests/performance/locustfile.py
```

**Capturar:** la sección de tasks de `CampusUser` mostrando los pesos.
Guardar como `screenshots/10-locustfile.png`.

---

## B. Capturas de Ejecución Exitosa

### B.1 Servicios K8s

```bash
kubectl get services -n circleguard-dev
```

**Capturar:** tabla con ClusterIPs y puertos.
Guardar como `screenshots/11-k8s-services.png`.

### B.2 Unit tests pasando

```bash
./gradlew :services:circleguard-auth-service:test :services:circleguard-form-service:test :services:circleguard-identity-service:test :services:circleguard-gateway-service:test --no-daemon
```

**Capturar:** terminal mostrando `BUILD SUCCESSFUL` y conteo de tests.
Guardar como `screenshots/12-unit-tests-pass.png`.

### B.3 JUnit report HTML

```bash
open services/circleguard-auth-service/build/reports/tests/test/index.html
```

**Capturar:** página con `JwtTokenServiceTest`, `QrTokenServiceTest` mostrando 100% green.
Guardar como `screenshots/13-junit-report.png`.

### B.4 Jacoco coverage HTML

```bash
open services/circleguard-auth-service/build/reports/jacoco/test/html/index.html
```

**Capturar:** la página de coverage con barras de porcentaje.
Guardar como `screenshots/14-jacoco-coverage.png`.

### B.5 Stage pipeline ejecutándose

```bash
bash scripts/run-stage-pipeline.sh 2>&1 | tee stage-run.log
```

**Capturar (durante la corrida):**
1. Al empezar — encabezado de cada stage
2. Salida del Locust con la tabla `Request Statistics`
3. Final con `STAGE pipeline complete`

Guardar la captura final como `screenshots/15-stage-pipeline-output.png`.

### B.6 Pods en namespace stage

```bash
kubectl get pods -n circleguard-stage
```

**Capturar:** 13 pods Running.
Guardar como `screenshots/16-k8s-stage-pods.png`.

### B.7 Locust HTML report — stage

```bash
open results/perf-stage.html
```

**Capturar tres pantallas:**
1. Tabla "Request Statistics"
2. Gráfica "Number of users / RPS"
3. Gráfica "Response Times"

Guardar como `screenshots/17-locust-stage-stats.png`, `18-locust-stage-rps.png`, `19-locust-stage-latency.png`.

### B.8 Master pipeline ejecutándose

```bash
AUTO_APPROVE=1 bash scripts/run-master-pipeline.sh 2>&1 | tee master-run.log
```

**Capturar:** secciones clave del log:
1. Build successful
2. Deploy to stage successful
3. System tests output con Locust stats
4. Approval gate (con AUTO_APPROVE)
5. Deploy to production successful
6. Release notes generated

Guardar como `screenshots/20-master-pipeline.png`.

### B.9 Pods en namespace master (production)

```bash
kubectl get pods -n circleguard-master
```

**Capturar:** mostrando **2 réplicas** corriendo de cada servicio.
Guardar como `screenshots/21-k8s-master-pods.png`.

### B.10 Release Notes generadas

```bash
ls -la RELEASE_NOTES_*.md
code RELEASE_NOTES_v1.0.*.md
```

**Capturar:**
1. Tabla de identificación al inicio
2. Sección "Categorized Changes"
3. Sección "Test Summary"
4. Sección "Services Deployed"
5. **Sección "Rollback Procedure"** (importante para CM)
6. Sección "CAB"

Guardar como `screenshots/22-release-notes-header.png`, `23-release-notes-changes.png`, `24-release-notes-tests.png`, `25-release-notes-rollback.png`.

### B.11 Git tag creado

```bash
git tag -l 'v1.0.*' | tail -5
```

**Capturar:** terminal con la lista de tags.
Guardar como `screenshots/26-git-tags.png`.

### B.12 Locust HTML report — master

```bash
open results/perf-master.html
```

**Capturar:** las mismas 3 vistas que en stage.
Guardar como `screenshots/27-locust-master-stats.png`, `28-locust-master-rps.png`, `29-locust-master-latency.png`.

---

## C. Capturas para análisis de rendimiento

Cuando ya tengas las gráficas de Locust, anota encima (con un editor de imagen tipo Preview o Skitch):
- Mediana en el endpoint de `/api/v1/gate/validate` (debe ser 3 ms)
- Throughput total en RPS
- Tasa de error (los 401/404 son esperados)

Las anotaciones hacen el reporte más fácil de leer durante la revisión.

---

## D. Lista de verificación final

Antes de entregar, asegúrate de tener:

- [ ] 29 capturas en `screenshots/`
- [ ] `REPORTE_TALLER_2.md` revisado
- [ ] `VIDEO_SCRIPT.md` revisado
- [ ] Video grabado y exportado como MP4 (máximo 8 min)
- [ ] `RELEASE_NOTES_v1.0.*.md` presente
- [ ] `results/` con todos los CSV y HTML
- [ ] Repo pusheado al remoto (último commit en `master`)
