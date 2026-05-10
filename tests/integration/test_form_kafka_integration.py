"""INTEGRATION TEST #2 - Form → Kafka (event publication)

Validates that form-service publishes a `survey.submitted` event to Kafka
when a survey is POSTed. This is the entry point of the asynchronous
contact-tracing pipeline (form → promotion → notification).
"""
import json
import time
import uuid
import pytest
import requests

KAFKA_TOPIC = "survey.submitted"


@pytest.fixture(scope="module")
def kafka_consumer(kafka_bootstrap):
    pytest.importorskip("kafka")
    from kafka import KafkaConsumer
    from kafka.errors import NoBrokersAvailable
    try:
        consumer = KafkaConsumer(
            KAFKA_TOPIC,
            bootstrap_servers=kafka_bootstrap,
            auto_offset_reset="latest",
            group_id=f"integration-test-{uuid.uuid4()}",
            consumer_timeout_ms=10_000,
            value_deserializer=lambda v: json.loads(v.decode("utf-8")) if v else None,
        )
    except NoBrokersAvailable:
        pytest.skip(f"Kafka not reachable at {kafka_bootstrap}")
    yield consumer
    consumer.close()


@pytest.fixture(scope="module")
def form_alive(hosts):
    try:
        r = requests.get(hosts["form"], timeout=3)
        if r.status_code not in (200, 401, 403, 404, 405):
            pytest.skip("form-service not responding")
    except requests.RequestException:
        pytest.skip("form-service unreachable — port-forward required")


def test_survey_submission_publishes_kafka_event(hosts, kafka_consumer, form_alive):
    anonymous_id = str(uuid.uuid4())
    payload = {
        "anonymousId": anonymous_id,
        "responses": {"q1": "NO", "q2": "NO"},
        "hasFever": False,
        "hasCough": False,
    }

    # Drain any backlog before the action
    list(kafka_consumer)  # iterates over latest messages until consumer_timeout

    # Publish the survey
    r = requests.post(f"{hosts['form']}/api/v1/surveys", json=payload, timeout=10)
    assert r.status_code in (200, 201), f"Survey submission failed: {r.status_code} {r.text}"

    # Wait for the Kafka event
    deadline = time.time() + 15
    found = False
    for msg in kafka_consumer:
        if time.time() > deadline:
            break
        try:
            if msg.value and str(msg.value.get("anonymousId")) == anonymous_id:
                found = True
                # Validate the event schema
                assert "hasSymptoms" in msg.value
                assert "timestamp" in msg.value
                break
        except (AttributeError, KeyError):
            continue

    assert found, f"Kafka event for anonymousId={anonymous_id} not found within 15s"
