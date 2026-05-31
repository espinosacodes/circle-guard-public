package com.circleguard.promotion.controller;

import com.circleguard.promotion.security.JwtAuthenticationFilter;
import com.circleguard.promotion.security.SecurityConfig;
import com.circleguard.promotion.security.TestRoleAuthenticationFilter;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * CG-012 - Integration test for the Health Center promotion endpoint.
 *
 * <p>Slice test ({@link WebMvcTest @WebMvcTest}) so we don't need
 * Postgres / Neo4j / Kafka. The Spring Security filter chain defined in
 * {@link SecurityConfig} is loaded via {@link Import @Import}, and the
 * {@link TestRoleAuthenticationFilter} injects roles via the
 * {@code X-Test-Role} header.</p>
 *
 * <p>{@link JwtAuthenticationFilter} is replaced with a Mockito mock that
 * acts as a pass-through filter (it only forwards the chain without
 * touching SecurityContext) so the test-role filter can take over.</p>
 */
@WebMvcTest(controllers = HealthCenterPromotionController.class)
@Import({SecurityConfig.class, TestRoleAuthenticationFilter.class})
@ActiveProfiles("test")
@TestPropertySource(properties = {
        // Required by JwtAuthenticationFilter's constructor — even though the
        // bean is mocked, Spring still has to resolve constructor properties
        // during the security autoconfig phase.
        "jwt.secret=test-test-test-test-test-test-test-test-test"
})
class HealthCenterPromotionIT {

    private static final String PATH = "/api/v1/promotion/health-center/promote";

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    @SuppressWarnings("rawtypes")
    private KafkaTemplate kafkaTemplate;

    /**
     * Mocked so the security filter chain initializes without a real JWT
     * verifier. We turn it into a pure pass-through filter in
     * {@link #setUp()} below.
     */
    @MockBean
    private JwtAuthenticationFilter jwtAuthenticationFilter;

    @BeforeEach
    void setUp() throws Exception {
        // Pass-through stub: invoke the next filter without doing anything.
        // Required because Mockito mocks of OncePerRequestFilter swallow
        // the chain by default, which would block every request.
        doAnswer(invocation -> {
            ServletRequest req = invocation.getArgument(0);
            ServletResponse res = invocation.getArgument(1);
            FilterChain chain = invocation.getArgument(2);
            chain.doFilter(req, res);
            return null;
        }).when(jwtAuthenticationFilter).doFilter(any(), any(), any());
    }

    private static final String VALID_PAYLOAD = """
            {
              "suspectHashId": "anon-abc-123",
              "evidenceUrl":   "https://s3.amazonaws.com/cg-evidence/r-2024-001.pdf",
              "reason":        "PCR result attached"
            }
            """;

    private static final String PAYLOAD_WITH_REAL_NAME = """
            {
              "suspectHashId": "anon-abc-123",
              "evidenceUrl":   "https://s3.amazonaws.com/cg-evidence/r-2024-001.pdf",
              "reason":        "Confirmed in conversation with John Smith"
            }
            """;

    @Test
    void unauthenticated_returns401_or_403() throws Exception {
        // Spring Security's default behaviour on an unauthenticated request
        // hitting a route guarded by hasRole(...) is 401 in stateless setups,
        // but 403 is also accepted because some filter chains rewrite it.
        mockMvc.perform(post(PATH)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(VALID_PAYLOAD))
                .andExpect(result -> {
                    int code = result.getResponse().getStatus();
                    assertThat(code).isIn(401, 403);
                });

        verify(kafkaTemplate, never()).send(anyString(), any(), any());
    }

    @Test
    void authenticatedAsNonOfficer_returns403() throws Exception {
        mockMvc.perform(post(PATH)
                        .header(TestRoleAuthenticationFilter.HEADER, "STUDENT")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(VALID_PAYLOAD))
                .andExpect(status().isForbidden());

        verify(kafkaTemplate, never()).send(anyString(), any(), any());
    }

    @Test
    void officer_returns202_andProducesKafkaEvent_withCorrelationId() throws Exception {
        MvcResult result = mockMvc.perform(post(PATH)
                        .header(TestRoleAuthenticationFilter.HEADER, "HEALTH_CENTER_OFFICER")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(VALID_PAYLOAD))
                .andExpect(status().isAccepted())
                .andReturn();

        JsonNode body = objectMapper.readTree(result.getResponse().getContentAsString());
        assertThat(body.has("correlationId")).isTrue();
        assertThat(body.get("correlationId").asText()).isNotBlank();
        assertThat(body.get("status").asText()).isEqualTo("ACCEPTED");

        // Verify the Kafka event was produced on the right topic with the
        // right key (== suspectHashId for partition affinity).
        verify(kafkaTemplate, times(1))
                .send(eq("promotion.confirmed"), eq("anon-abc-123"), any());
    }

    @Test
    void payloadWithRealName_returns422_andProducesNoEvent() throws Exception {
        mockMvc.perform(post(PATH)
                        .header(TestRoleAuthenticationFilter.HEADER, "HEALTH_CENTER_OFFICER")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(PAYLOAD_WITH_REAL_NAME))
                .andExpect(status().isUnprocessableEntity());

        verify(kafkaTemplate, never()).send(anyString(), any(), any());
    }
}
