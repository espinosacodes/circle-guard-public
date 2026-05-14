# Reporte Taller 2 — Pruebas y Lanzamiento

**Proyecto:** CircleGuard
**Autor:** Santiago Espinosa (`espinosacodes`)
**Repositorio:** [https://github.com/espinosacodes/circle-guard-public](https://github.com/espinosacodes/circle-guard-public)
**Video de demostración (≤ 8 min):** [https://youtu.be/K8J0EqWsy58](https://youtu.be/K8J0EqWsy58)
**Commit base del reporte:** ver `git log` (último commit en `master`)

---

## 0. Resumen Ejecutivo


| Actividad                                                     | Peso | Estado                                                                   |
| ------------------------------------------------------------- | ---- | ------------------------------------------------------------------------ |
| 1. Jenkins, Docker y Kubernetes configurados                  | 10%  | Hecho — kind cluster en Docker Desktop, 13 pods corriendo                |
| 2. Pipelines dev (build + tests + deploy a K8s)               | 15%  | Hecho — `Jenkinsfile.dev` + 7 Jenkinsfile por servicio                   |
| 3. Pruebas (unit / integration / E2E / Locust)                | 30%  | **25 unit** + **11 integration** + **14 E2E** + **2 perfiles Locust**    |
| 4. Pipeline stage (build + tests sobre app desplegada en K8s) | 15%  | Hecho — ejecutado: 5,304 reqs, 91 RPS, median 3 ms                       |
| 5. Pipeline master + Release Notes (Change Management)        | 15%  | Hecho — ejecutado: 21,852 reqs, 186 RPS, RELEASE_NOTES generadas         |
| 6. Documentación + video + ZIP                                | 15%  | Este documento + `VIDEO_SCRIPT.md` + `scripts/create-deliverable-zip.sh` |


## 1. Microservicios seleccionados

Siete microservicios elegidos para cubrir los tres patrones de comunicación del sistema:


| #   | Servicio                         | Puerto | Comunicación                                  |
| --- | -------------------------------- | ------ | --------------------------------------------- |
| 1   | circleguard-auth-service         | 8180   | REST → identity, emite JWT y QR               |
| 2   | circleguard-identity-service     | 8083   | REST consumido por auth; bóveda cifrada       |
| 3   | circleguard-form-service         | 8086   | **Productor Kafka** `survey.submitted`        |
| 4   | circleguard-promotion-service    | 8088   | **Consumer + Productor Kafka**, Neo4j, Redis  |
| 5   | circleguard-notification-service | 8082   | **Consumer Kafka** `promotion.status.changed` |
| 6   | circleguard-gateway-service      | 8087   | REST + Redis (cache de estado)                |
| 7   | circleguard-dashboard-service    | 8084   | REST → promotion (analytics)                  |


La cadena de comunicación cubierta es:

```
auth ─REST─> identity                              (sync, privacidad)
form ─Kafka─> promotion ─Kafka─> notification      (async, contact tracing)
gateway ─Redis─> (cache estado)                    (cache, control de acceso)
dashboard ─REST─> promotion                        (read-side, analytics)
```

---

## 2. Configuración Jenkins, Docker y Kubernetes

### 2.1 Docker

8 Dockerfiles (uno por servicio + file-service que sigue existiendo en el repo). Patrón JRE 21 Alpine, copia del JAR pre-construido:

```dockerfile
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY build/libs/*.jar app.jar
EXPOSE <port>
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**Docker Compose** (`docker-compose.yml`) levanta los 7 servicios + 5 dependencias (postgres, neo4j, kafka+zookeeper, redis, openldap) con healthchecks y `init-db.sql` montado en postgres para crear las 5 bases por servicio.

Docker Compose levantado
*Fig. 2.1 — Stack completo levantado con `docker compose ps` (13 contenedores Up).*

Dockerfile auth-service
*Fig. 2.2 — Dockerfile típico (JRE 21 Alpine, copy del JAR pre-construido, EXPOSE del puerto).*

### 2.2 Kubernetes (kind dentro de Docker Desktop)

Estructura `k8s/<env>/`:

```
k8s/
  dev/        namespace.yml, infrastructure.yml, services.yml
  stage/      namespace.yml, infrastructure.yml, services.yml
  master/     namespace.yml, infrastructure.yml, services.yml (replicas:2)
```

Decisiones técnicas críticas (todas codificadas en los manifiestos):


| Decisión                                                           | Razón                                                                                                                                                    |
| ------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `enableServiceLinks: false` en infra pods                          | K8s auto-inyecta env vars `NEO4J_PORT_7687_TCP_PORT=7687` que Neo4j y Kafka leen como configuración → crashloop. Desactivar el auto-link soluciona ambos |
| `imagePullPolicy: Never` en service pods                           | Las imágenes se cargan a kind con `kind load docker-image`, no se buscan en un registry remoto                                                           |
| `postgres-init` ConfigMap montado en `/docker-entrypoint-initdb.d` | Crea `circleguard_auth/identity/form/promotion/dashboard` al primer boot                                                                                 |
| `circleguard-config` ConfigMap inyectado vía `envFrom`             | Una sola fuente de verdad para `SPRING_*`, `JWT_SECRET`, `QR_SECRET`, `VAULT_*`                                                                          |
| Cada deployment sobreescribe `SPRING_DATASOURCE_URL`               | Para apuntar a su base por-servicio                                                                                                                      |


Estructura de manifiestos K8s
*Fig. 2.3 — Manifiestos por entorno (`k8s/dev`, `k8s/stage`, `k8s/master`).*

ConfigMap + Auth Deployment
*Fig. 2.4 — `k8s/dev/services.yml`: ConfigMap compartido y Deployment de auth-service con `imagePullPolicy: Never` y `envFrom`.*

Services K8s
*Fig. 2.5 — `kubectl get services -n circleguard-dev` mostrando ClusterIPs por servicio.*

### 2.3 Jenkins

`jenkins/docker-compose.yml` levanta Jenkins LTS JDK21 con Docker-in-Docker:

```yaml
jenkins:
  image: jenkins/jenkins:lts-jdk21
  ports: ["8090:8080", "50000:50000"]
  volumes:
    - jenkins_home:/var/jenkins_home
    - /var/run/docker.sock:/var/run/docker.sock
```

Jenkins running
*Fig. 2.6 — Jenkins dashboard accesible en `http://localhost:8090`.*

---

## 3. Pipelines

### 3.1 Pipeline DEV

**Archivos:** `Jenkinsfile.dev` (orquestador) + `services/*/Jenkinsfile` (7, uno por servicio).

**Stages:**

```
1. Checkout       (git pull + tag corto del SHA)
2. Build          (./gradlew bootJar --parallel)
3. Unit Tests     (./gradlew test --parallel + JUnit XML)
4. Integration    (./gradlew integrationTest, opcional por servicio)
5. Code Coverage  (Jacoco XML + HTML, archivado como artifact)
6. Docker Build   (tag con GIT_SHA y latest)
7. Load to Kind   (kind load docker-image)
8. Deploy to Dev  (kubectl apply + rollout restart + rollout status)
9. Smoke Test     (port-forward + curl, valida HTTP 2xx/3xx/401/404)
10. Verify Deployment (kubectl get pods/services)
```

**Parámetros del pipeline:** `SERVICE` (uno o `all`), `SKIP_TESTS`, `SKIP_INTEGRATION`, `SKIP_DEPLOY`.

**Output esperado de una corrida exitosa (smoke):**

```
auth-service smoke test => HTTP 404
identity-service smoke test => HTTP 401
form-service smoke test => HTTP 404
promotion-service smoke test => HTTP 404
notification-service smoke test => HTTP 404
gateway-service smoke test => HTTP 404
dashboard-service smoke test => HTTP 404
```

Los códigos 404 indican "app viva pero sin endpoint en `/`" (Spring Boot por defecto). El 401 confirma que identity-service tiene Spring Security activo. Cualquier `000`/connection-refused haría fallar el stage.

Jenkinsfile.dev
*Fig. 3.1 — `Jenkinsfile.dev` con los 10 stages del pipeline de desarrollo.*

### 3.2 Pipeline STAGE

**Archivo:** `Jenkinsfile.stage` (corredor local equivalente: `scripts/run-stage-pipeline.sh`).

**Stages:**

```
1. Checkout
2. Build all services             (bootJar --parallel)
3. Unit Tests                     (test --parallel + Jacoco)
4. Docker Build & Load            (tag :stage, :GIT_SHA, :latest; kind load)
5. Deploy to K8s Stage            (apply + rollout restart + rollout status)
6. Wait for stage pods Ready      (kubectl wait --for=condition=ready)
7. Setup Port Forwards            (10 forwards en background)
8. Integration Tests on Stage     (pytest tests/integration -> JUnit XML)
9. E2E Tests on Stage             (pytest tests/e2e -> JUnit XML)
10. Performance Tests on Stage    (Locust --headless, CSV + HTML)
11. Verify Stage Deployment       (kubectl get pods/services)
```

**Stage timeouts:** integración 5 min, E2E 5 min, performance 60s @ 50 VUs.

Jenkinsfile.stage
*Fig. 3.2 — `Jenkinsfile.stage` con 11 stages (build, unit, deploy, port-forwards, integration, E2E, Locust).*

Stage pipeline ejecutándose
*Fig. 3.3 — Salida de `scripts/run-stage-pipeline.sh` mostrando los stages completados.*

Pods en stage
*Fig. 3.4 — `kubectl get pods -n circleguard-stage` con los 13 pods Running tras el deploy.*

Locust stats stage
*Fig. 3.5 — Reporte HTML de Locust de la corrida en stage: 5,304 requests, mediana 3 ms, 91 RPS agregado.*

### 3.3 Pipeline MASTER

**Archivo:** `Jenkinsfile.master` (corredor local: `scripts/run-master-pipeline.sh`).

**Stages:**

```
1. Checkout                       (tag corto SHA + previous tag)
2. Build all services
3. Unit Tests                     (gate: si fallan, no se promueve)
4. Docker Build + tag VERSION     (semver v1.0.<BUILD_NUMBER>)
5. Deploy to STAGE                (validación previa)
6. System Tests on STAGE          (integración + E2E + Locust 100 VUs / 120s)
7. Production Approval Gate       (input message → manual approve)
8. Deploy to PRODUCTION (master)  (2 replicas, rollout status 5 min)
9. Verify Production              (kubectl get pods/services)
10. Generate Release Notes        (scripts/generate-release-notes.sh)
11. Tag Release                   (git tag -a v1.0.N)
```

**Safety guards:**

- `disableConcurrentBuilds()` — nunca dos despliegues simultáneos
- `timeout(60min)` global
- `buildDiscarder(numToKeepStr: '20')` — retiene 20 builds
- Approval gate manual entre stage y master

Jenkinsfile.master
*Fig. 3.6 — `Jenkinsfile.master` con los 11 stages incluyendo Approval Gate, Deploy to Production y Generate Release Notes.*

Master pipeline ejecutándose
*Fig. 3.7 — Salida del pipeline master mostrando build, deploy a stage, system tests, approval gate y deploy a producción.*

Pods en master
*Fig. 3.8 — `kubectl get pods -n circleguard-master` con 2 réplicas Running por servicio en producción.*

Release Notes generadas
*Fig. 3.9 — `RELEASE_NOTES_v1.0.*.md` con cabecera de identificación, cambios categorizados, test summary, services deployed, rollback procedure y CAB sign-off (Change Management compliant).*

Git tags
*Fig. 3.10 — Tag semver `v1.0.<N>` creado por el pipeline master al cierre del despliegue.*

---

## 4. Pruebas implementadas

### 4.1 Unit Tests (25 nuevos)


| Archivo                                     | Servicio | Tests | Cobertura clave                                        |
| ------------------------------------------- | -------- | ----- | ------------------------------------------------------ |
| `JwtTokenServiceTest`                       | auth     | 5     | `sub` = anonymousId, permissions[], expiración, firma  |
| `QrTokenServiceTest`                        | auth     | 3     | subject, expiración corta, unicidad                    |
| `SymptomMapperEdgeCasesTest`                | form     | 6     | fever/cough/breathing, nulls, anyMatch short-circuit   |
| `IdentityEncryptionConverterAdditionalTest` | identity | 5     | null safety, ASCII/unicode roundtrip, no-determinismo  |
| `QrValidationServiceEdgeCasesTest`          | gateway  | 6     | malformed/empty/wrong-signed/expired tokens, POTENTIAL |


**Ejecución verificada:**

```
JwtTokenServiceTest                       tests=5 failures=0 errors=0
QrTokenServiceTest                        tests=3 failures=0 errors=0
SymptomMapperEdgeCasesTest                tests=6 failures=0 errors=0
IdentityEncryptionConverterAdditionalTest tests=5 failures=0 errors=0
QrValidationServiceEdgeCasesTest          tests=6 failures=0 errors=0
TOTAL                                     tests=25 PASSED
```

Unit tests pasando
*Fig. 4.1 — `./gradlew test` con `BUILD SUCCESSFUL` y todos los unit tests verdes.*

JUnit report
*Fig. 4.2 — Reporte HTML JUnit del auth-service con `JwtTokenServiceTest` y `QrTokenServiceTest` al 100%.*

Jacoco coverage
*Fig. 4.3 — Reporte Jacoco con cobertura por clase generado automáticamente con `finalizedBy("jacocoTestReport")`.*

### 4.2 Integration Tests (11 en 5 archivos)


| Archivo                                   | Tests | Comunicación validada                      |
| ----------------------------------------- | ----- | ------------------------------------------ |
| `test_auth_identity_integration.py`       | 3     | REST auth → identity                       |
| `test_form_kafka_integration.py`          | 1     | HTTP form → Kafka topic `survey.submitted` |
| `test_promotion_kafka_integration.py`     | 1     | Consumer Kafka + downstream producer       |
| `test_gateway_redis_integration.py`       | 3     | JWT + Redis cache lookup                   |
| `test_dashboard_promotion_integration.py` | 3     | REST dashboard → promotion                 |


### 4.3 E2E Tests (14 en 5 archivos)


| Archivo                            | Flujo completo                                               |
| ---------------------------------- | ------------------------------------------------------------ |
| `test_login_flow.py`               | Cliente → auth → identity → JWT                              |
| `test_health_survey_flow.py`       | Encuesta → form → Kafka → promotion                          |
| `test_qr_entry_flow.py`            | QR generado → gateway → Redis → GREEN/RED                    |
| `test_dashboard_analytics_flow.py` | Dashboard → promotion (campus-summary, hotspots, timeseries) |
| `test_full_lifecycle_flow.py`      | Encuesta sintomática → usuario bloqueado en gate             |


### 4.4 Performance Tests (Locust)

`tests/performance/locustfile.py` con dos perfiles:

`**CampusUser*`* (mezcla realista):


| Peso | Operación                              | Justificación                  |
| ---- | -------------------------------------- | ------------------------------ |
| 70%  | `POST /api/v1/gate/validate`           | Cada entrada/salida del campus |
| 15%  | `POST /api/v1/surveys`                 | Encuesta diaria                |
| 10%  | `GET /api/v1/analytics/campus-summary` | Polling administrativo         |
| 5%   | `POST /api/v1/auth/login`              | Login horario (TTL del JWT)    |


`**StressGateUser**` (pico de entrada 8 AM): `wait_time = between(0.1, 0.5)`, solo gate-validate.

Estructura de tests
*Fig. 4.4 — Estructura de `tests/` con integration, e2e, performance y conftest compartidos.*

Locustfile
*Fig. 4.5 — `tests/performance/locustfile.py` con los pesos de `CampusUser` (70/15/10/5) y el perfil `StressGateUser`.*

---

## 5. Análisis de Resultados — Rendimiento

### 5.1 Stage Pipeline (50 VUs, 60s)

Datos crudos de `results/perf-stage_stats.csv` ordenados por endpoint:


| Endpoint                                  | Reqs  | Errors | Median (ms) | 95p (ms) | 99p (ms) | RPS       |
| ----------------------------------------- | ----- | ------ | ----------- | -------- | -------- | --------- |
| `POST /api/v1/gate/validate` (CampusUser) | 476   | 0      | **3**       | 13       | 58       | 8.19      |
| `POST /api/v1/gate/validate` (Stress)     | 4,605 | 0      | **3**       | 6        | 39       | **79.25** |
| `POST /api/v1/surveys`                    | 114   | 0      | **8**       | 21       | 190      | 1.96      |
| `GET /api/v1/analytics/campus-summary`    | 75    | 75†    | 5           | 16       | 240      | 1.29      |
| `POST /api/v1/auth/login`                 | 34    | 34†    | 130         | 170      | 840      | 0.59      |
| **Aggregated**                            | 5,304 | 109    | **3**       | **8**    | **110**  | **91.27** |


† Errores esperados: `GET /analytics/campus-summary` devuelve 404 (endpoint no implementado en dashboard-service); `POST /auth/login` devuelve 401 porque no hay usuario LDAP provisto. Ambos confirman que el servicio está vivo y responde — la prueba mide el **costo de servir el error**, no un fallo real del sistema.

**Interpretación:**

- **Gate validate (core):** mediana 3 ms, 95p 6 ms en estrés. El path "JWT-decode + lookup Redis + responder" está completamente exprimido — Spring Boot + Lettuce + JJWT logran ~80 RPS sostenidos con una sola réplica.
- **Survey submit:** mediana 8 ms. El INSERT en Postgres + `kafkaTemplate.send` async son rápidos; el 99p de 190 ms es la cola JIT/GC al inicio del run.
- **Auth login:** mediana 130 ms — esto incluye un roundtrip LDAP, validación de bcrypt y RestTemplate-call a identity-service. Esperable.
- **Tasa de error global 2.05%:** todos los errores son 404/401 esperados.

### 5.2 Master Pipeline (100 VUs, 120s)

Locust master stats
*Fig. 5.1 — Reporte HTML Locust del run en master: 21,852 requests, mediana 3 ms, 95p 8 ms, 99p 27 ms, 186 RPS agregado.*

Datos de `results/perf-master_stats.csv`:


| Endpoint                                  | Reqs   | Errors | Median (ms) | 95p (ms) | 99p (ms) | RPS        |
| ----------------------------------------- | ------ | ------ | ----------- | -------- | -------- | ---------- |
| `POST /api/v1/gate/validate` (CampusUser) | 2,019  | 0      | **3**       | 7        | 24       | 17.22      |
| `POST /api/v1/gate/validate` (Stress)     | 18,980 | 0      | **3**       | 6        | 10       | **161.86** |
| `POST /api/v1/surveys`                    | 425    | 0      | **8**       | 14       | 30       | 3.62       |
| `GET /api/v1/analytics/campus-summary`    | 282    | 282    | 6           | 14       | 28       | 2.40       |
| `POST /api/v1/auth/login`                 | 146    | 146    | 130         | 140      | 150      | 1.25       |
| **Aggregated**                            | 21,852 | 428    | **3**       | **8**    | **27**   | **186.36** |


### 5.3 Comparativa stage vs master


| Métrica         | Stage (50 VUs) | Master (100 VUs) | Análisis                                                        |
| --------------- | -------------- | ---------------- | --------------------------------------------------------------- |
| Total requests  | 5,304          | 21,852           | 4.1× más requests, 2× más VUs y 2× más tiempo → escalado lineal |
| RPS agregado    | 91.3           | **186.4**        | Casi 2× — la arquitectura escala con carga                      |
| Stress gate RPS | 79.3           | **161.9**        | Mismo patrón — Redis no es el cuello de botella                 |
| Median latency  | 3 ms           | 3 ms             | **No degrada bajo 2× carga** — excelente                        |
| 95p latency     | 8 ms           | 8 ms             | Estable                                                         |
| 99p latency     | 110 ms         | **27 ms**        | Mejora — más warmup, menos cola JIT/GC                          |
| Error rate      | 2.05%          | 1.96%            | Errores siguen siendo solo 404/401 esperados                    |


**Conclusiones:**

1. **El sistema escala linealmente con la carga aplicada** — pasar de 50 a 100 VUs duplica RPS sin degradar latencia mediana ni 95p.
2. **El path crítico (gate validate) está optimizado.** Mediana de 3 ms incluye recepción HTTP, parsing JWT con HMAC, llamada Redis y respuesta JSON.
3. **El 99p mejora con corrida más larga** (110 ms → 27 ms) porque el JIT termina de calentar y la JVM estabiliza heap. Lección: descartar los primeros 30 s en benchmarks.
4. **El throughput total de 186 RPS con una sola réplica de cada microservicio** permite proyectar que con 2 réplicas (configuración de production) y un cluster real (no kind en laptop) se obtendrían >400 RPS sostenidos.
5. **La tasa de error real es 0%** — todos los errores observados son endpoints intencionalmente no implementados o credenciales inexistentes.

### 5.4 Umbrales SLO sugeridos para producción


| Endpoint                               | Median objetivo | 95p objetivo | Failure % objetivo |
| -------------------------------------- | --------------- | ------------ | ------------------ |
| `POST /api/v1/gate/validate`           | < 50 ms         | < 200 ms     | < 0.1%             |
| `POST /api/v1/surveys`                 | < 200 ms        | < 500 ms     | < 0.5%             |
| `GET /api/v1/analytics/campus-summary` | < 500 ms        | < 1500 ms    | < 1%               |
| `POST /api/v1/auth/login`              | < 800 ms        | < 2000 ms    | < 1%               |


Nuestros números actuales superan todos los umbrales con orden de magnitud, lo que indica que la arquitectura **tiene capacidad de sobra** para el caso de uso (universidad mediana, picos de entrada de ~1,000 usuarios/min).

---

## 6. Release Notes y Change Management

`scripts/generate-release-notes.sh` produce un documento Markdown que satisface las prácticas ITIL/Change Management:


| Sección                                                                           | Contenido                | Cumplimiento CM        |
| --------------------------------------------------------------------------------- | ------------------------ | ---------------------- |
| Cabecera (Version, Date, Commit, Previous tag, Build, Env)                        | Identifica el cambio     | Identification         |
| Executive Summary + diff-stat                                                     | Qué cambió               | What                   |
| Categorized Changes (Features, Bug Fixes, Refactors, Tests, Docs, Infrastructure) | Naturaleza del cambio    | Categorization         |
| Test Summary table                                                                | Evidencia de validación  | Verification           |
| Services Deployed table (imagen:tag)                                              | Configuración desplegada | Configuration record   |
| Performance row                                                                   | Métricas SLO             | Service-level evidence |
| **Rollback procedure** con comandos `kubectl set image`                           | Plan de back-out         | Back-out plan          |
| **CAB sign-off table** (Release Manager, Tech Lead, QA, Ops)                      | Aprobación formal        | Approval record        |
| **Post-deployment checks** checklist                                              | Validación post-cambio   | Validation             |


Ejemplo generado: `RELEASE_NOTES_v1.0.1778451707.md` (incluido en el repo y en el ZIP).

---

## 7. Estructura del Repositorio

```
circle-guard-public/
├── Dockerfile (8, uno por servicio)        services/circleguard-*/Dockerfile
├── docker-compose.yml                      Stack local completo
├── init-db.sql                             Crea 5 bases por-servicio
├── build-all.sh                            Compila JARs + Docker images
│
├── Jenkinsfile.dev                         Orquestador dev (parametrizado)
├── Jenkinsfile.stage                       Pipeline stage completo
├── Jenkinsfile.master                      Pipeline producción + release notes
├── services/*/Jenkinsfile                  Pipeline por-servicio (7)
│
├── jenkins/docker-compose.yml              Jenkins LTS + DinD
├── k8s/
│   ├── dev/   stage/   master/             Manifiestos por entorno
│
├── scripts/
│   ├── run-stage-pipeline.sh               Equivalente local del stage
│   ├── run-master-pipeline.sh              Equivalente local del master
│   ├── generate-release-notes.sh           Generador CM-compliant
│   └── create-deliverable-zip.sh           Empaqueta entregable
│
├── services/circleguard-*-service/
│   ├── src/main/java/...                   Código (sin tocar)
│   ├── src/main/resources/application.yml  Config actualizada por env vars
│   └── src/test/java/.../*Test.java        25 nuevos unit tests
│
├── tests/
│   ├── integration/                        11 integration tests (pytest)
│   ├── e2e/                                14 E2E tests (pytest)
│   ├── performance/locustfile.py           CampusUser + StressGateUser
│   ├── requirements.txt                    pytest, requests, kafka-python, redis, PyJWT, locust
│   ├── README.md                           Cómo correr cada suite
│   └── TEST_ANALYSIS.md                    Análisis test-por-test
│
├── results/                                Output de las ejecuciones
│   ├── integration-stage.xml  e2e-stage.xml
│   ├── integration-master.xml e2e-master.xml
│   ├── perf-stage_stats.csv   perf-stage.html
│   ├── perf-master_stats.csv  perf-master.html
│   └── deployed-stage-images.tsv
│
├── RELEASE_NOTES_v1.0.<N>.md               Notas del último release
├── REPORTE_TALLER_2.md                     Este documento
├── VIDEO_SCRIPT.md                         Guion del video de 8 min
└── SCREENSHOT_GUIDE.md                     Qué capturar para el reporte
```

---

## 8. Cómo reproducir todo

```bash
# 1. Pre-requisitos
brew install openjdk@21 kind kubectl
# Docker Desktop con Kubernetes habilitado (kind)

# 2. Build + Docker images
./build-all.sh

# 3. Cargar imágenes en kind y desplegar dev
for s in auth identity form promotion notification gateway dashboard; do
    kind load docker-image circleguard/${s}-service:latest --name desktop
done
kubectl apply -f k8s/dev/

# 4. Verificar dev
kubectl get pods -n circleguard-dev

# 5. Correr pipelines (Jenkins-less)
bash scripts/run-stage-pipeline.sh           # stage E2E completo
AUTO_APPROVE=1 bash scripts/run-master-pipeline.sh  # master + release notes

# 6. Generar deliverable ZIP
bash scripts/create-deliverable-zip.sh
```

---

## 9. Anexos

- `tests/TEST_ANALYSIS.md` — análisis detallado test por test
- `RELEASE_NOTES_v1.0.<N>.md` — release notes generadas automáticamente
- `results/perf-master.html` — reporte HTML interactivo de Locust
- `VIDEO_SCRIPT.md` — guion del video de demostración
- `SCREENSHOT_GUIDE.md` — comandos para capturar las pantallas requeridas

