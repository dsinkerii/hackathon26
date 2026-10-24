package com.playground.security;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
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

@SpringBootTest(classes = ru.playground.PlaygroundApplication.class, properties = {
        "app.ingest.token=test-ingest-token",
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

        mvc.perform(get("/api/v1/incidents"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].description").value("Обнаружен незнакомый посетитель"));

        mvc.perform(get("/api/v1/persons"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].status").value("PENDING"))
                .andExpect(jsonPath("$[0].visitCount").value(1));
    }

    @Test
    void confirmsPersonUsingTheFlutterPostRoute() throws Exception {
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

        String personsJson = mvc.perform(get("/api/v1/persons"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].status").value("PENDING"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String personId = objectMapper.readTree(personsJson).get(0).get("id").asText();

        mvc.perform(post("/api/v1/persons/{id}/confirm", personId))
                .andExpect(status().isNoContent());

        mvc.perform(get("/api/v1/persons"))
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

        mvc.perform(get("/api/v1/incidents"))
                .andExpect(jsonPath("$.length()").value(1));
    }
}
