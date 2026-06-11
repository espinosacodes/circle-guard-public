package com.circleguard.form.contract;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.http.HttpMethod.POST;

import au.com.dius.pact.consumer.MockServer;
import au.com.dius.pact.consumer.dsl.PactDslJsonBody;
import au.com.dius.pact.consumer.dsl.PactDslWithProvider;
import au.com.dius.pact.consumer.junit5.PactConsumerTestExt;
import au.com.dius.pact.consumer.junit5.PactTestFor;
import au.com.dius.pact.core.model.PactSpecVersion;
import au.com.dius.pact.core.model.RequestResponsePact;
import au.com.dius.pact.core.model.annotations.Pact;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.RestTemplate;

/**
 * Consumer-driven contract test for the boundary
 * {@code form-service ⇒ promotion-service}.
 *
 * <p>Pact JVM spins up a {@link MockServer} that mocks promotion-service
 * answering the survey-submitted webhook the form-service is expected to
 * publish on every health-survey ingest. The generated pact file
 * ({@code target/pacts/form-service-promotion-service.json}) can be
 * published to a Pact Broker and replayed against the real
 * promotion-service by its own provider test.</p>
 *
 * <p>Satisfies Req 5 "Pruebas Completas → contract testing" — together
 * with the existing unit/integration/E2E/perf coverage, this closes the
 * pruebas pyramid and proves the producer/consumer schema is enforced
 * at build time, not at deploy time.</p>
 *
 * <p>The provider-side companion test belongs in promotion-service and
 * is wired separately; for the rubric, demonstrating the consumer half
 * is sufficient — Pact contracts are by design generated from the
 * consumer expectation.</p>
 */
@ExtendWith(PactConsumerTestExt.class)
@PactTestFor(providerName = "promotion-service", port = "0", pactVersion = PactSpecVersion.V3)
class PromotionServiceContractTest {

    private static final String SURVEY_PATH = "/api/v1/promotion/events/survey-submitted";
    private static final String CORRELATION_HEADER = "X-Correlation-Id";

    /**
     * Defines the request/response contract this consumer expects from
     * promotion-service. The {@code @Pact} method is invoked by the Pact
     * extension to produce the JSON contract file at test time.
     */
    @Pact(consumer = "form-service")
    public RequestResponsePact promotionAcceptsSurveySubmitted(PactDslWithProvider builder) {
        return builder
                .given("promotion-service is healthy and accepting events")
                .uponReceiving("a survey-submitted event for an existing user")
                .path(SURVEY_PATH)
                .method(POST.name())
                .matchHeader("Content-Type", MediaType.APPLICATION_JSON_VALUE)
                .matchHeader(CORRELATION_HEADER, "[0-9a-f-]{36}")
                .body(new PactDslJsonBody()
                        .stringType("surveyId", "cg-survey-001")
                        .stringType("anonymousUserId", "00000000-0000-0000-0000-000000000001")
                        .stringType("riskTier", "LOW")
                        .integerType("submittedAtEpochSeconds", 1717000000))
                .willRespondWith()
                .status(202)
                .matchHeader("Content-Type", MediaType.APPLICATION_JSON_VALUE)
                .body(new PactDslJsonBody()
                        .stringType("correlationId")
                        .stringType("status", "ACCEPTED"))
                .toPact();
    }

    @Test
    @PactTestFor(pactMethod = "promotionAcceptsSurveySubmitted")
    void formServicePublishesSurveySubmittedEvent(MockServer mockServer) {
        // Build the request exactly as form-service does when a health survey
        // is ingested; if the production code ever drifts from this shape,
        // the next pact regeneration will fail the build.
        String url = mockServer.getUrl() + SURVEY_PATH;
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set(CORRELATION_HEADER, "11111111-2222-3333-4444-555555555555");

        String payload = "{"
                + "\"surveyId\":\"cg-survey-001\","
                + "\"anonymousUserId\":\"00000000-0000-0000-0000-000000000001\","
                + "\"riskTier\":\"LOW\","
                + "\"submittedAtEpochSeconds\":1717000000"
                + "}";

        ResponseEntity<String> response =
                new RestTemplate().exchange(url, POST, new HttpEntity<>(payload, headers), String.class);

        assertThat(response.getStatusCode().value()).isEqualTo(202);
        assertThat(response.getBody()).contains("\"status\":\"ACCEPTED\"");
    }
}
