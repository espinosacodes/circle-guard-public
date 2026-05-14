# Guion del Video — Taller 2 (max 8 minutos)

## Pre-producción

Antes de grabar, levanta todo:

```bash
# Terminal 1: Docker Desktop con Kubernetes ON, kind cluster activo
kubectl get nodes   # debe mostrar desktop-control-plane Ready

# Terminal 2: deploy actual
kubectl apply -f k8s/dev/
kubectl wait --for=condition=ready pod --all -n circleguard-dev --timeout=180s
kubectl get pods -n circleguard-dev

# Terminal 3: Jenkins (opcional, solo si vas a mostrar UI)
cd jenkins && docker-compose up -d
open http://localhost:8090
```

Abre 3 ventanas en pantalla:
- Izquierda: terminal con `kubectl get pods -n circleguard-dev -w`
- Centro: VS Code mostrando los archivos clave
- Derecha: navegador con `results/perf-master.html` y/o Jenkins UI

---

## Estructura (8:00 total)

| Tiempo | Sección | Duración |
|-------:|---------|---------:|
| 0:00 – 0:30 | Intro y resumen | 0:30 |
| 0:30 – 1:30 | Actividad 1: Docker + K8s + Jenkins | 1:00 |
| 1:30 – 2:30 | Actividad 2: Pipeline dev | 1:00 |
| 2:30 – 4:00 | Actividad 3: Pruebas (unit / integration / E2E / Locust) | 1:30 |
| 4:00 – 5:00 | Actividad 4: Pipeline stage ejecutándose | 1:00 |
| 5:00 – 6:30 | Actividad 5: Pipeline master + release notes | 1:30 |
| 6:30 – 7:30 | Análisis de resultados de rendimiento | 1:00 |
| 7:30 – 8:00 | Cierre y entregables | 0:30 |

---

## Guion detallado

### 0:00 – 0:30  Intro

> "Hola, soy Santiago Espinosa. Este es el Taller 2: pruebas y lanzamiento del proyecto CircleGuard. Escogí 7 microservicios que se comunican entre sí — auth llama a identity por REST, form publica eventos a Kafka que consume promotion y luego notification, y gateway valida QR contra Redis. Voy a mostrar la configuración de infra, los 3 pipelines, las pruebas a todos los niveles y los resultados de performance."

**Pantalla:** README del repo + diagrama de comunicación (Sección 1 del reporte).

### 0:30 – 1:30  Actividad 1 — Infra

> "Empezamos con la infra. Docker Compose levanta los 7 servicios más Postgres, Neo4j, Kafka, Redis y OpenLDAP. Cada servicio tiene su Dockerfile JRE 21 Alpine. En Kubernetes uso kind dentro de Docker Desktop con 3 namespaces: dev, stage y master."

**Comandos a ejecutar / mostrar:**
```bash
# Mostrar contenedores Docker
docker compose -f docker-compose.yml config --services

# Mostrar manifiestos K8s
ls k8s/dev/ k8s/stage/ k8s/master/

# Mostrar pods corriendo en dev
kubectl get pods -n circleguard-dev
```

**Énfasis (callouts en pantalla):**
- 13 pods Running (7 services + 6 infra)
- `enableServiceLinks: false` resuelve el crashloop de Neo4j/Kafka
- `imagePullPolicy: Never` porque las imágenes están en kind, no en un registry

### 1:30 – 2:30  Actividad 2 — Pipeline dev

> "El pipeline dev tiene 10 stages. Lo central: build, unit tests con Jacoco, docker build, load a kind, deploy, smoke test."

**Mostrar:**
```bash
# Estructura del Jenkinsfile
sed -n '50,80p' Jenkinsfile.dev    # los stages

# Por servicio
ls services/circleguard-*-service/Jenkinsfile

# Correr unit tests para evidenciar
./gradlew :services:circleguard-auth-service:test --no-daemon | tail -10
```

**Pantalla:** Jenkinsfile.dev abierto en VS Code, scroll por los stages. Mostrar el output `BUILD SUCCESSFUL` y los 25 unit tests pasando.

### 2:30 – 4:00  Actividad 3 — Pruebas

> "Implementé 25 unit tests nuevos: JWT, QR, encriptación, validación de síntomas y QR validation edge cases. Para integración y E2E uso pytest contra los servicios desplegados — 11 integration y 14 E2E. Performance con Locust, dos perfiles: CampusUser realista con mezcla de operaciones y StressGateUser para pico de entrada."

**Comandos:**
```bash
# Lista de tests
find services/*/src/test -name '*Test.java' | xargs grep -l '@Test' | wc -l
ls tests/integration tests/e2e tests/performance

# Mostrar uno (ej. SymptomMapperEdgeCasesTest)
code services/circleguard-form-service/src/test/java/com/circleguard/form/service/SymptomMapperEdgeCasesTest.java

# Locustfile
code tests/performance/locustfile.py
```

**Pantalla:** abrir Jacoco report HTML (`services/.../build/reports/jacoco/test/html/index.html`) y mostrar cobertura visualmente.

### 4:00 – 5:00  Actividad 4 — Pipeline stage

> "El pipeline stage va más allá: después del build y unit, despliega a K8s stage, abre port-forwards, y corre integration + E2E + Locust contra la app desplegada."

**Comando a ejecutar (o reproducir grabación):**
```bash
bash scripts/run-stage-pipeline.sh
```

**Pantalla:** mostrar la corrida real (o saltar al output con `cat results/perf-stage.html` en navegador). Resaltar:
- Pods desplegados en `circleguard-stage`
- Tabla de resultados Locust en consola
- `results/perf-stage.html` con gráficas

### 5:00 – 6:30  Actividad 5 — Pipeline master + Release Notes

> "El pipeline master orquesta todo: build, unit, deploy a stage, sistema de tests sobre stage, approval gate manual, deploy a producción con 2 réplicas, y al final genera Release Notes siguiendo Change Management."

**Pantalla:** abrir `RELEASE_NOTES_v1.0.<N>.md` en VS Code y hacer scroll por:
- Tabla de identificación (version, date, commit, previous tag)
- Categorized Changes (features, bug fixes, infrastructure)
- Test Summary table
- Services Deployed
- **Rollback Procedure** (resaltar esta sección)
- CAB sign-off
- Post-deployment checks

**Comando opcional:**
```bash
# Última corrida del master
ls -la RELEASE_NOTES_*.md | tail -1
head -50 RELEASE_NOTES_v1.0.*.md | tail -40
```

### 6:30 – 7:30  Análisis de resultados de rendimiento

> "Los números de la corrida en master: 21,852 requests en 120s con 100 VUs. Mediana 3 ms, percentil 95 en 8 ms, 99 en 27 ms, throughput 186 RPS, tasa de error 1.96% — todos los errores son 401 o 404 esperados por endpoints sin implementar o credenciales sin provisionar."

**Pantalla:** Abrir `results/perf-master.html` y mostrar las gráficas. Mostrar también la tabla comparativa stage vs master del REPORTE_TALLER_2.md sección 5.3.

**Énfasis (callouts):**
- Latencia mediana NO degrada al pasar de 50 a 100 VUs → escala lineal
- Stress gate: 162 RPS sostenidos con una sola réplica
- 99p mejora de 110ms (stage) a 27ms (master) porque el JIT calienta

### 7:30 – 8:00  Cierre y entregables

> "Resumen: 7 microservicios, 3 pipelines, 25 unit tests + 11 integration + 14 E2E + Locust, deploy validado en Kubernetes con generación automática de release notes ITIL-compliant. Entrego el ZIP con todo: pipelines, tests, manifiestos K8s, código modificado y resultados. Repositorio en GitHub: espinosacodes/circle-guard-public. Gracias."

**Pantalla:** `tree -L 2 -I 'build|node_modules|.gradle'` o un screenshot de la estructura.

---

## Capturas de pantalla a tener listas durante la grabación

1. `kubectl get pods -n circleguard-dev` con todos en Running
2. Jenkinsfile.dev abierto en VS Code mostrando los stages
3. Output del comando `./gradlew test` con BUILD SUCCESSFUL
4. `results/perf-stage.html` en navegador
5. `results/perf-master.html` en navegador
6. `RELEASE_NOTES_v1.0.*.md` abierto en VS Code
7. `kubectl get pods -n circleguard-master` con 2 réplicas cada uno
8. Diagrama de comunicación de microservicios (Sección 1 del reporte)

## Tips de grabación

- Software: QuickTime (macOS) o OBS Studio (cross-platform)
- Resolución: 1080p mínimo
- Cursor visible (en macOS: System Settings → Accessibility → Display → Pointer size)
- Habla a velocidad normal — 8 minutos da margen para no sentir prisa
- Haz un guion en bullet, no leas el texto palabra por palabra
- Graba sin audio primero, luego dobla la narración si te equivocas mucho
- Acelera 1.25× los momentos de build/deploy que sean repetitivos
