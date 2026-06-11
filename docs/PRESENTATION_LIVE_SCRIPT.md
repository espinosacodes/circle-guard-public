# CircleGuard — Guion de presentación en vivo (10 min)

**Equipo:** Santiago Espinosa + Carlos
**Formato:** demo en vivo (sin diapositivas) — terminal, Postman/curl, GitLab UI, GCP Console, OCI Console, código en VSCode
**Total:** 10:00 minutos · 6 bloques de rúbrica cubiertos

---

## Pre-flight (HACER 15 min ANTES de presentar)

En 4 terminales separadas, dejá corriendo:

```bash
# Terminal 1 — Grafana
kubectl port-forward -n observability svc/kps-grafana 3000:80

# Terminal 2 — Jaeger
kubectl port-forward -n observability svc/jaeger-query 16686:16686

# Terminal 3 — Kiali
istioctl dashboard kiali

# Terminal 4 — Gateway service (para curl/Postman)
kubectl port-forward -n circleguard-dev svc/gateway-service 8080:8080
```

**Tabs ya abiertos en el navegador (en este orden):**
1. https://gitlab.com/espinosacodes/circle-guard-final/-/boards/11343311
2. https://gitlab.com/espinosacodes/circle-guard-final/-/pipelines
3. https://sonarcloud.io/project/overview?id=espinosacodes_circle-guard-final
4. https://console.cloud.google.com/kubernetes/clusters/details/us-central1/circleguard-dev-gke/details?project=circleguard-final-cfs-2026
5. https://cloud.oracle.com/containers/clusters?region=sa-bogota-1
6. http://localhost:3000 (Grafana — admin / `CircleGuardDev2026!`)
7. http://localhost:20001 (Kiali)
8. http://localhost:16686 (Jaeger)
9. Postman con la colección importada (o `docs/PRESENTATION_LIVE_SCRIPT.md` abierto al lado)
10. VSCode en `services/circleguard-auth-service/src/main/java/com/circleguard/auth/client/IdentityClient.java`

---

## 🎬 BLOQUE 1 — Apertura (00:00 → 00:45)

> **Driver:** Santiago (teclado) · **Speaker:** Santiago

[Mostrar: pestaña de **GitLab Kanban board**]

**SANTIAGO:** *"Buenas. Somos Santiago Espinosa y Carlos. Proyecto final de IngeSoft V. CircleGuard es un sistema de rastreo de contactos universitario — **8 microservicios** en Spring Boot 3 y Java 21, sobre Kubernetes, con CI/CD en GitLab, multi-cloud GCP más Oracle Cloud, observabilidad completa, Istio y Chaos Mesh."*

[Tipear en terminal]
```bash
git log --oneline -10
```

**SANTIAGO:** *"Tenemos 16 de 23 historias cerradas, dos sprints completos, GitFlow con Conventional Commits — todo trazable de issue a deploy."*

---

## 🏗️ BLOQUE 2 — Arquitectura + Infraestructura (00:45 → 02:45) `2 min`

> **Driver:** Carlos · **Speaker:** Carlos + Santiago

[Carlos abre VSCode en `infra/terraform/`]
```bash
tree infra/terraform -L 2
```

**CARLOS:** *"Infraestructura como código en Terraform. **8 módulos** — 5 de GCP, 3 de OCI — y 3 ambientes: dev, stage, prod. El estado remoto está en un bucket GCS."*

[Carlos cambia a la pestaña de **GCP Console — GKE**]

**CARLOS:** *"En GCP tenemos el cluster `circleguard-dev-gke` corriendo en `us-central1`, **4 nodos** spot."*

[Tipear]
```bash
kubectl get nodes
kubectl get pods -n circleguard-dev
```

**CARLOS:** *"**14 pods running**: los 8 microservicios más Postgres, Redis, Kafka, Zookeeper, Neo4j y OpenLDAP."*

[Santiago toma el teclado, cambia a pestaña de **OCI Console**]

**SANTIAGO:** *"Para el bono multi-cloud, **Oracle Cloud** como secundario en la región Bogotá. Lo muestro real:"*

[Tipear]
```bash
oci ce cluster get \
  --cluster-id ocid1.cluster.oc1.sa-bogota-1.aaaaaaaazjxtxctwwyq7gcztx5xnsbishj4kyzd2du2rdkxwtcehoufi66mq \
  --query 'data.{name:name, state:"lifecycle-state", k8s:"kubernetes-version"}' \
  --output table
```

**SANTIAGO:** *"Cluster `circleguard-stage-oke` ACTIVE, Kubernetes 1.33.10. El node pool quedó pendiente porque Oracle Bogotá hoy está sin capacidad — el módulo está completo en el repo, espera el `terraform apply` cuando libere."*

---

## 📦 BLOQUE 3 — Aplicación funcionando (02:45 → 04:15) `1:30`

> **Driver:** Santiago · **Speaker:** Santiago

[Cambiar a terminal con port-forward del gateway en 8080]

**SANTIAGO:** *"La aplicación está viva. Probemos el flujo end-to-end por la API gateway."*

[Comando 1 — health]
```bash
curl -s http://localhost:8080/actuator/health/liveness
# Esperado: {"status":"UP"}
```

[Comando 2 — login → JWT]
```bash
curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"jdoe","password":"demo"}' | jq .
```

**SANTIAGO:** *"Auth-service responde, emite un JWT. Ese token sirve para el siguiente endpoint, que es el **caso de uso central**: un oficial del centro de salud promueve a un estudiante de Suspect a Confirmed, y el saga dispara las notificaciones."*

[Comando 3 — Postman o curl con el JWT]
```bash
TOKEN="<paste-the-jwt>"
curl -s -X POST http://localhost:8080/api/v1/promotion/health-center/promote \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"suspectHashId":"a3f9b2c1...","evidenceUrl":"s3://demo/evidence.pdf","reason":"PCR positiva"}'
# Esperado: 202 Accepted + correlationId
```

**SANTIAGO:** *"202 Accepted, correlation ID. En paralelo:"*

[En otra terminal — opcional, mostrar logs]
```bash
kubectl logs -n circleguard-dev deploy/promotion-service --tail=20
```

---

## 🚀 BLOQUE 4 — CI/CD (04:15 → 05:45) `1:30`

> **Driver:** Carlos · **Speaker:** Carlos

[Pestaña de GitLab → Pipelines]

**CARLOS:** *"GitLab CI con **14 stages**: build, test, quality, security, package, security-image, deploy-dev, deploy-stage, e2e, perf, zap, deploy-prod, release, notify."*

[Click en una pipeline verde] → expandir stages

**CARLOS:** *"Cada commit dispara la pipeline. Build paralelo de los 8 servicios con `parallel:matrix`. Test con cobertura JaCoCo. Quality gate con **SonarCloud** —"*

[Cambiar a pestaña de SonarCloud]

**CARLOS:** *"— acá está el análisis: code smells, coverage, security hotspots, el Quality Gate."*

[Volver a GitLab pipeline] → mostrar artefactos

**CARLOS:** *"Security: **Trivy** escaneando filesystem y la imagen del contenedor, **OWASP ZAP** baseline, y un **SBOM con syft** en CycloneDX. Para producción, gate manual:"*

[Pipeline de un tag `v*`] → mostrar el botón `▶` manual en `deploy:prod`

**CARLOS:** *"Solo maintainers pueden disparar prod. Versionado semántico automático con `semantic-release` leyendo los Conventional Commits."*

---

## 📊 BLOQUE 5 — Dashboards de monitoreo (05:45 → 07:15) `1:30`

> **Driver:** Santiago · **Speaker:** Santiago

[Abrir Grafana en `http://localhost:3000` (admin / `CircleGuardDev2026!`)]

**SANTIAGO:** *"Stack de observabilidad: **kube-prometheus-stack** + **Loki** + **Jaeger**, todo en el namespace `observability`."*

[Dashboard "CircleGuard / Auth Service"]

**SANTIAGO:** *"Por cada servicio: RPS, latencia p50/p95/p99, error rate, JVM heap, y el estado del circuit breaker de Resilience4j."*

[Switch a dashboard "CircleGuard / Business Metrics"]

**SANTIAGO:** *"Métricas de negocio reales: `circleguard_promotions_total`, latencia de promoción p95, check-ins por minuto, círculos activos. Las emitimos con Micrometer desde el código."*

[Cambiar a Kiali — `http://localhost:20001`]

**SANTIAGO:** *"**Istio service mesh** — Kiali muestra el grafo del mesh, mTLS strict habilitado entre todos los servicios, y las AuthorizationPolicies para RBAC a nivel de mesh."*

[Cambiar a Jaeger — `http://localhost:16686`]

**SANTIAGO:** *"**Tracing distribuido** con OpenTelemetry y Jaeger. Cualquier request cruzando 3-4 servicios queda registrada acá con su correlation ID. Sampling del 10%."*

---

## ⚡ BLOQUE 6 — Pruebas de rendimiento + Patrones (07:15 → 08:30) `1:15`

> **Driver:** Carlos · **Speaker:** Carlos + Santiago

[Carlos abre `results/perf/SAMPLE_REPORT.md`]

**CARLOS:** *"Stress testing con **Locust** y **k6** en paralelo. Resultado del smoke run:"*

| Métrica | Valor | SLO |
|---|---|---|
| p50 latency | 88.7 ms | — |
| p95 latency | 143.3 ms | <200 ms ✓ |
| p99 latency | 175.2 ms | <500 ms ✓ |
| Error rate | 0.00 % | <1 % ✓ |

[Santiago toma el teclado, abre VSCode en `IdentityClient.java`]

**SANTIAGO:** *"Patrones de diseño — Req 3. **Circuit Breaker** con Resilience4j envolviendo las llamadas a identity-service:"*

[Mostrar las líneas]
```java
@CircuitBreaker(name = "identity-service", fallbackMethod = "fallback")
@Retry(name = "identity-service")
public UUID getAnonymousId(String realIdentity) { ... }
```

**SANTIAGO:** *"Y **Feature Toggle** en dashboard-service, controlado por ConfigMaps de Kubernetes — flip sin redeploy. **Pact contract test** entre auth e identity:"*

[Mostrar `tests/contracts/auth-service-identity-service.pact.json` brevemente]

---

## 🎓 BLOQUE 7 — Lecciones aprendidas y recomendaciones (08:30 → 09:45) `1:15`

> **Speakers:** alternan Carlos y Santiago

[Abrir `docs/RUBRIC_CHECKLIST.md` en GitLab]

**CARLOS:** *"Lo que funcionó muy bien: la **trazabilidad completa** desde una historia de usuario en el board, pasa a una rama `feature/CG-XXX`, pasa a un MR con Conventional Commit, dispara la pipeline, deploya y deja el trace en Jaeger. Cero pasos manuales en el medio."*

**SANTIAGO:** *"Lo que tuvimos que pivotear: el plan original era GCP más Azure. Mi cuenta de Azure de estudiante quedó bloqueada, entonces pivoteamos a **Oracle Cloud** — `Always Free` tier en Bogotá. Esa decisión nos costó tiempo pero el módulo Terraform quedó portable: cambiar de proveedor secundario es ahora un swap de 3 módulos."*

**CARLOS:** *"Otro aprendizaje: el GCP free trial expiró a la mitad del proyecto. Tuvimos que reprovisionar todo desde cero en un proyecto nuevo. El backend remoto y los `tfvars` documentados hicieron que el redeploy fuera de **15 minutos**. Conclusión: la documentación de infraestructura paga rapidísimo."*

**SANTIAGO:** *"Recomendación para futuros equipos: **no depender de un solo trial de cloud** y **arrancar con el `terraform apply` el primer día** — no esperar. También: invertir en los runbooks de operación temprano; los hicimos al final y se notó."*

[Cambiar a pantalla de auto-evaluación]

**CARLOS:** *"Auto-evaluación honesta: **109 sobre 120** con todo lo demostrado hoy. Las gaps están documentadas explícitamente en `PROJECT_COMPLETION.md` sección 3."*

---

## 🙏 BLOQUE 8 — Cierre + Q&A (09:45 → 10:00) `0:15`

> **Speaker:** Santiago

**SANTIAGO:** *"Todo lo que vieron — código, infra, docs, screenshots — está en `gitlab.com/espinosacodes/circle-guard-final`. La pestaña principal de la rúbrica con evidencias por requisito es `docs/PROJECT_COMPLETION.md`. Gracias, abrimos preguntas."*

[Dejar abierta la pestaña del Kanban board para que el profesor pueda mirar mientras pregunta]

---

## 📋 División de roles

| Quién | Bloques que LIDERA | Tipo de trabajo |
|---|---|---|
| **Santiago** | 1 (apertura), 3 (app), 5 (dashboards), parte de 6 (patrones), 7 (lecciones), 8 (cierre) | Frontend de la demo (app, observabilidad, código) |
| **Carlos** | 2 (infra), 4 (CI/CD), parte de 6 (perf), 7 (lecciones) | Backend de la demo (infra, pipeline, performance) |

Patrón: **uno tiene el teclado, el otro habla**. Cambian cada bloque.

---

## ⚠️ Plan B si algo falla en vivo

| Si falla… | Mostrá esto en su lugar |
|---|---|
| Port-forward de Grafana | `screenshots/final/32-grafana-namespace-pods.png` |
| Pipeline en vivo | Pipeline verde anterior (link directo) + `screenshots/final/31-prometheus-targets.png` |
| OCI console no responde | `oci ce cluster get` por CLI (mismo output, sin browser) |
| curl al gateway | `kubectl logs -n circleguard-dev deploy/gateway-service --tail=5` para mostrar que está vivo |
| Kiali no carga | `kubectl get authorizationpolicies,virtualservices -A` |
| Jaeger sin trazas | `kubectl get pods -n observability` + `screenshots/final/33-kiali-mesh-graph.png` |

---

## 🎯 Frases clave para defender bajo presión

| Si te preguntan… | Respondé |
|---|---|
| *"¿Por qué Loki y no ELK?"* | "Loki indexa solo labels, ELK indexa todo el cuerpo. Para nuestro volumen (8 servicios), Loki es 3× más barato en storage. La consulta en Grafana Explore equivale a Kibana. Decisión documentada en `OBSERVABILITY.md` §6." |
| *"¿Por qué Resilience4j y no Hystrix?"* | "Hystrix está en mantenimiento desde 2018. Resilience4j es funcionalmente equivalente y mantenido activamente." |
| *"¿Por qué el cluster OCI no tiene workers?"* | "Oracle Bogotá retorna `Out of host capacity` en las 4 familias de shape que probamos hoy (A1.Flex, E2.1.Micro, E2.1, E4.Flex). Es una limitación del proveedor en esta región, no de nuestra IaC. El módulo Terraform está completo y queda esperando capacidad." |
| *"¿Cuánto cuesta esto?"* | "Dev en GCP: 30-60 USD/mes. OCI: 0 USD (Always Free). El detalle está en `docs/COSTS.md`." |
| *"¿Qué harían diferente?"* | "Tres cosas: contract tests de Pact desde el sprint 1 (no al final), runbooks paralelos al desarrollo, y el `terraform apply` el primer día." |

---

**Última revisión:** corre el deck completo en seco al menos UNA vez con cronómetro antes del día D. Apuntá los segundos donde te trabás y editá las frases.
