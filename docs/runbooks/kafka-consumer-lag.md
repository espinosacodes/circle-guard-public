# Runbook: Kafka consumer lag

Applies to alert:
* `KafkaConsumerLag` (Sev-2)

---

## 1. Symptoms

* Slack alert in `#circleguard-warnings` with `consumergroup` and `topic`
  labels.
* Notification / dashboard latency increases (events stale).
* `kafka_consumergroup_lag` panel on the Kafka dashboard shows growth.

## 2. Dashboards / commands to open first

1. Grafana -> Kafka exporter dashboard -> select the affected
   `consumergroup` and `topic`.
2. Grafana Explore -> Loki:

   ```
   {namespace="circleguard-prod", app=~"circleguard-(notification|promotion)-service"}
     |= "consumer" or "kafka"
   ```

3. Confirm the broker side is healthy (no `ServiceDown` for Kafka).
4. CLI sanity check from inside the cluster:

   ```
   kubectl -n kafka exec kafka-0 -- \
     kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
     --describe --group <consumergroup>
   ```

   The CURRENT-OFFSET vs LOG-END-OFFSET delta = the lag per partition.

## 3. Mitigation steps

### A. Consumer pods are healthy but lag keeps growing

The consumer cannot keep up. Increase parallelism:

1. Scale the Deployment:

   ```
   kubectl -n circleguard-prod scale deploy/circleguard-<svc> --replicas=6
   ```

   (Maximum useful replicas == number of partitions on the topic.)

2. If at max replicas and still lagging, **increase partition count**:

   ```
   kubectl -n kafka exec kafka-0 -- \
     kafka-topics.sh --bootstrap-server localhost:9092 \
     --alter --topic <topic> --partitions <new>
   ```

   (Beware: partition count is monotonically increasing, and re-keys
   change ordering — coordinate with the producer team.)

### B. Consumer is stuck on a poison message

1. Find the offending message in Loki — search for the exception
   stacktrace.
2. If the service has a DLQ topic configured, manually advance the
   offset past the bad record:

   ```
   kubectl -n kafka exec kafka-0 -- \
     kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
     --group <consumergroup> --topic <topic> \
     --reset-offsets --to-offset <next> --execute
   ```

3. File a bug to make the consumer skip-and-DLQ on the same shape of
   payload.

### C. Broker is slow / hot

1. Check `KafkaBrokerNetworkIn` / `KafkaBrokerNetworkOut` panels.
2. If a single broker is saturated, trigger a leader rebalance:

   ```
   kubectl -n kafka exec kafka-0 -- \
     kafka-leader-election.sh --bootstrap-server localhost:9092 \
     --election-type preferred --all-topic-partitions
   ```

## 4. Verification

* Consumer lag panel decreases back to single-digit thousands within 30
  minutes.
* Alert auto-resolves.

## 5. Escalation

| Step                          | Owner                          | Contact                                 |
|-------------------------------|--------------------------------|-----------------------------------------|
| First responder               | on-call SRE                    | PagerDuty rotation `circleguard-sre`    |
| 30 minutes unresolved         | Kafka platform owner           | `@kafka-platform` in Slack              |
| Data-loss risk (DLQ overflow) | Engineering Manager + Product  | `#circleguard-incident-channel`         |
