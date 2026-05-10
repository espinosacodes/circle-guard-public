package com.circleguard.form.service;

import com.circleguard.form.model.HealthSurvey;
import com.circleguard.form.model.Question;
import com.circleguard.form.model.QuestionType;
import com.circleguard.form.model.Questionnaire;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/**
 * UNIT TEST #3 - SymptomMapper edge cases (NEW)
 *
 * Existing SymptomMapperTest covers happy path (fever YES, fever NO).
 * This adds edge-case coverage to prevent silent regressions in the rule
 * engine that drives the SUSPECT/ACTIVE status promotion.
 */
class SymptomMapperEdgeCasesTest {

    private SymptomMapper mapper;
    private Question coughQ;
    private Question breathingQ;
    private Question unrelatedQ;

    @BeforeEach
    void setUp() {
        mapper = new SymptomMapper();
        coughQ = Question.builder().id(UUID.randomUUID())
                .text("Persistent cough?").type(QuestionType.YES_NO).build();
        breathingQ = Question.builder().id(UUID.randomUUID())
                .text("Difficulty breathing?").type(QuestionType.YES_NO).build();
        unrelatedQ = Question.builder().id(UUID.randomUUID())
                .text("Have you traveled recently?").type(QuestionType.YES_NO).build();
    }

    @Test
    @DisplayName("Detects cough as a symptom keyword")
    void detectsCough() {
        Questionnaire q = questionnaire(coughQ);
        HealthSurvey s = surveyWithResponses(Map.of(coughQ.getId().toString(), "YES"));
        assertTrue(mapper.hasSymptoms(s, q));
    }

    @Test
    @DisplayName("Detects breathing difficulty as a symptom keyword")
    void detectsBreathingDifficulty() {
        Questionnaire q = questionnaire(breathingQ);
        HealthSurvey s = surveyWithResponses(Map.of(breathingQ.getId().toString(), "YES"));
        assertTrue(mapper.hasSymptoms(s, q));
    }

    @Test
    @DisplayName("Returns false when only an unrelated question is answered YES")
    void unrelatedYesAnswerDoesNotTriggerSymptom() {
        Questionnaire q = questionnaire(unrelatedQ);
        HealthSurvey s = surveyWithResponses(Map.of(unrelatedQ.getId().toString(), "YES"));
        // 'travel' is not a symptom keyword → must NOT trigger
        assertFalse(mapper.hasSymptoms(s, q));
    }

    @Test
    @DisplayName("Returns false when responses map is null")
    void noSymptomsWhenResponsesNull() {
        Questionnaire q = questionnaire(coughQ);
        HealthSurvey s = HealthSurvey.builder().responses(null).build();
        assertFalse(mapper.hasSymptoms(s, q));
    }

    @Test
    @DisplayName("Returns false when questionnaire is null")
    void noSymptomsWhenQuestionnaireNull() {
        HealthSurvey s = surveyWithResponses(Map.of(coughQ.getId().toString(), "YES"));
        assertFalse(mapper.hasSymptoms(s, null));
    }

    @Test
    @DisplayName("Stops at first symptom found (anyMatch short-circuits)")
    void detectsAnyOneSymptomFromMultiple() {
        Questionnaire q = questionnaire(coughQ, breathingQ, unrelatedQ);
        HealthSurvey s = surveyWithResponses(Map.of(
                coughQ.getId().toString(), "NO",
                breathingQ.getId().toString(), "YES",  // <-- this one triggers
                unrelatedQ.getId().toString(), "YES"));
        assertTrue(mapper.hasSymptoms(s, q));
    }

    private Questionnaire questionnaire(Question... questions) {
        return Questionnaire.builder()
                .id(UUID.randomUUID())
                .questions(List.of(questions))
                .build();
    }

    private HealthSurvey surveyWithResponses(Map<String, Object> responses) {
        return HealthSurvey.builder()
                .anonymousId(UUID.randomUUID())
                .responses(responses)
                .build();
    }
}
