package com.playground.security;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
        "app.ingest.token=test-ingest-token",
        "app.security.jwt-secret=test-jwt-signing-secret-that-is-at-least-32-characters-long",
        "app.security.initial-admin-username=test-admin",
        "app.security.initial-admin-password=test-admin-password-123",
        "spring.datasource.url=jdbc:h2:mem:playground-test;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE"
})
@AutoConfigureMockMvc
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
class OperatorApiTest {
    @Autowired
    private MockMvc mvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void ingestCreatesIncidentAndPendingPersonUsingFlutterJsonShapes() throws Exception {
        String adminToken = login("test-admin", "test-admin-password-123");
        mvc.perform(post("/api/v1/incidents")
                        .header("X-Ingest-Token", "test-ingest-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "type": "STRANGER_DETECTED",
                                  "occurredAt": "2026-10-24T10:00:00Z",
                                  "trackId": "track-1"
                                }
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").isNotEmpty())
                .andExpect(jsonPath("$.type").value("STRANGER_DETECTED"))
                .andExpect(jsonPath("$.occurredAt").value("2026-10-24T10:00:00Z"));

        mvc.perform(get("/api/v1/incidents")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].description").value("Обнаружен незнакомый посетитель"));

        mvc.perform(get("/api/v1/persons")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].status").value("PENDING"))
                .andExpect(jsonPath("$[0].visitCount").value(1));
    }

    @Test
    void confirmsPersonUsingTheFlutterPostRoute() throws Exception {
        String adminToken = login("test-admin", "test-admin-password-123");
        mvc.perform(post("/api/v1/incidents")
                        .header("X-Ingest-Token", "test-ingest-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "type": "STRANGER",
                                  "occurredAt": "2026-10-24T10:00:00Z"
                                }
                                """))
                .andExpect(status().isCreated());

        String personsJson = mvc.perform(get("/api/v1/persons")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].status").value("PENDING"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String personId = objectMapper.readTree(personsJson).get(0).get("id").asText();

        mvc.perform(post("/api/v1/persons/{id}/confirm", personId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isNoContent());

        mvc.perform(get("/api/v1/persons")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(jsonPath("$[0].status").value("TRUSTED"));
    }

    @Test
    void requiresConfiguredIngestToken() throws Exception {
        mvc.perform(post("/api/v1/incidents")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"type":"VEHICLE_IN_ZONE","occurredAt":"2026-10-24T10:00:00Z"}
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    void deduplicatesRepeatedTrackEventsWithinTheConfiguredWindow() throws Exception {
        String adminToken = login("test-admin", "test-admin-password-123");
        String event = """
                {
                  "type": "VEHICLE_IN_ZONE",
                  "occurredAt": "2026-10-24T10:00:00Z",
                  "trackId": "vehicle-track-7"
                }
                """;

        mvc.perform(post("/api/v1/incidents")
                        .header("X-Ingest-Token", "test-ingest-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(event))
                .andExpect(status().isCreated());

        mvc.perform(post("/api/v1/incidents")
                        .header("X-Ingest-Token", "test-ingest-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(event))
                .andExpect(status().isOk());

        mvc.perform(get("/api/v1/incidents")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(jsonPath("$.length()").value(1));
    }

    @Test
    void requiresLoginForAdminApisAndAllowsAdminToManageRecordingCatalog() throws Exception {
        mvc.perform(get("/api/v1/cameras"))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/recordings"))
                .andExpect(status().isUnauthorized());

        String token = login("test-admin", "test-admin-password-123");
        String cameraJson = mvc.perform(post("/api/v1/cameras")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"North gate","location":"Main entrance","enabled":true}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("North gate"))
                .andReturn().getResponse().getContentAsString();
        String cameraId = objectMapper.readTree(cameraJson).get("id").asText();

        mvc.perform(post("/api/v1/recordings")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "cameraId":"%s",
                                  "title":"Gate event",
                                  "eventType":"VEHICLE_IN_ZONE",
                                  "recordedAt":"2026-10-24T10:00:00Z",
                                  "durationSeconds":45,
                                  "videoUrl":"https://example.test/recording.mp4"
                                }
                                """.formatted(cameraId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.cameraName").value("North gate"));

        mvc.perform(get("/api/v1/recordings")
                        .header("Authorization", "Bearer " + token)
                        .param("cameraId", cameraId)
                        .param("from", "2026-10-24T09:00:00Z")
                        .param("to", "2026-10-24T11:00:00Z"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1));

        mvc.perform(get("/api/v1/recordings")
                        .header("Authorization", "Bearer " + token)
                        .param("from", "2026-10-24T11:00:00Z")
                        .param("to", "2026-10-24T10:00:00Z"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_DATE_RANGE"));
    }

    @Test
    void bootstrapAdminCanCreateAccountsAndOnlyAdminsCanManageThem() throws Exception {
        String adminToken = login("test-admin", "test-admin-password-123");
        String userJson = mvc.perform(post("/api/v1/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"operator-one","password":"operator-password-123","role":"OPERATOR"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.role").value("OPERATOR"))
                .andReturn().getResponse().getContentAsString();

        String userId = objectMapper.readTree(userJson).get("id").asText();
        String operatorToken = login("operator-one", "operator-password-123");
        mvc.perform(get("/api/v1/users")
                        .header("Authorization", "Bearer " + operatorToken))
                .andExpect(status().isForbidden());

        mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch(
                                "/api/v1/users/{id}/enabled", userId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"enabled\":false}"))
                .andExpect(status().isOk());

        mvc.perform(get("/api/v1/cameras")
                        .header("Authorization", "Bearer " + operatorToken))
                .andExpect(status().isUnauthorized());
    }

    private String login(String username, String password) throws Exception {
        String response = mvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                java.util.Map.of("username", username, "password", password))))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return objectMapper.readTree(response).get("accessToken").asText();
    }
}
