# Release Notes — v1.0.1778451707

| Field             | Value                                  |
|-------------------|----------------------------------------|
| **Version**       | v1.0.1778451707                             |
| **Release Date**  | 2026-05-10 22:21 UTC                                |
| **Commit**        | 340d69a                             |
| **Previous tag**  | <none>                    |
| **Build**         | #local                |
| **Environment**   | Production (circleguard-master)        |

## Executive Summary

This release deploys all seven CircleGuard microservices to the production
Kubernetes namespace `circleguard-master`. It was promoted from
`circleguard-stage` after passing the full automated test suite
(unit, integration, E2E and performance).

```
 153 files changed, 17879 insertions(+)
```

---

## Categorized Changes (all commits)

### Features

- Add unit, integration, E2E and performance tests (340d69a, espinosacodes)
- Add dev pipelines per service with build, tests, deploy stages (5964ae3, espinosacodes)
- Add implementation on front and back (dce49ac, Juan Carlos Muñoz)

### Bug Fixes

- Fix Kafka/Neo4j crashloop in K8s with enableServiceLinks: false (6e833db, espinosacodes)

### Infrastructure

- Add unit, integration, E2E and performance tests (340d69a, espinosacodes)
- Add dev pipelines per service with build, tests, deploy stages (5964ae3, espinosacodes)
- Fix Kafka/Neo4j crashloop in K8s with enableServiceLinks: false (6e833db, espinosacodes)
- Remove file-service, keep 7 microservices for pipeline (75d4da8, espinosacodes)
- Configure Jenkins, Docker and Kubernetes infrastructure (81f4685, espinosacodes)


## Test Summary

| Suite              | Count       | Result   |
|--------------------|------------:|----------|
| Unit Tests         | 73    | PASSED   |
| Integration Tests  | 11     | PASSED   |
| E2E Tests          | 14     | PASSED   |
| Performance        | see below   | RECORDED |

### Performance (Locust aggregated)
```
,Aggregated,21852,428,3,4.833748031072641,1.162958000001879,902.318374999993,65.74949661358228,186.35786717707242,3.6500625641491395,3,4,4,5,6,8,11,27,140,150,900
```

## Services Deployed

| Service                | Image                                                     |
|------------------------|-----------------------------------------------------------|
| auth-service           | circleguard/auth-service:latest |
| dashboard-service      | circleguard/dashboard-service:latest |
| form-service           | circleguard/form-service:latest |
| gateway-service        | circleguard/gateway-service:latest |
| identity-service       | circleguard/identity-service:latest |
| kafka                  | confluentinc/cp-kafka:7.6.0 |
| neo4j                  | neo4j:5.26 |
| notification-service   | circleguard/notification-service:latest |
| openldap               | osixia/openldap:1.5.0 |
| postgres               | postgres:16 |
| promotion-service      | circleguard/promotion-service:latest |
| redis                  | redis:7.2 |
| zookeeper              | confluentinc/cp-zookeeper:7.6.0 |

## Rollback Procedure

If post-deployment monitoring detects regressions, roll back with:

```bash
# 1. Revert each service to the previous image tag
kubectl set image deployment/auth-service         auth-service=circleguard/auth-service:previous                 -n circleguard-master
kubectl set image deployment/identity-service     identity-service=circleguard/identity-service:previous         -n circleguard-master
kubectl set image deployment/form-service         form-service=circleguard/form-service:previous                 -n circleguard-master
kubectl set image deployment/promotion-service    promotion-service=circleguard/promotion-service:previous       -n circleguard-master
kubectl set image deployment/notification-service notification-service=circleguard/notification-service:previous -n circleguard-master
kubectl set image deployment/gateway-service      gateway-service=circleguard/gateway-service:previous           -n circleguard-master
kubectl set image deployment/dashboard-service    dashboard-service=circleguard/dashboard-service:previous       -n circleguard-master

# 2. Watch the rollback complete
kubectl rollout status deployment --timeout=300s -n circleguard-master
```

Alternatively, `kubectl rollout undo deployment/<name> -n circleguard-master`
restores the previous ReplicaSet without needing to know the tag.

## Change Advisory Board (CAB)

| Role               | Name                | Signature / Date |
|--------------------|---------------------|------------------|
| Release Manager    | _________________   | _________________ |
| Tech Lead          | _________________   | _________________ |
| QA Lead            | _________________   | _________________ |
| Operations         | _________________   | _________________ |

## Post-Deployment Checks

- [ ] All pods in `circleguard-master` show `1/1 Ready` (`kubectl get pods -n circleguard-master`)
- [ ] Gate validation responds < 200ms p95 (Grafana / Locust replay)
- [ ] No Kafka consumer lag on `promotion.status.changed`
- [ ] Identity vault row counts match pre-deployment within ±0.1%
- [ ] Audit log shows no decryption failures during the first hour

---
*Automatically generated by CircleGuard Master Pipeline.*
