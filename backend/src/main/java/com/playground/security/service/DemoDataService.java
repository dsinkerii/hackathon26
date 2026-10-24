package com.playground.security.service;

import com.playground.security.entity.Incident;
import com.playground.security.entity.Person;
import com.playground.security.entity.PersonStatus;
import com.playground.security.repository.IncidentRepository;
import com.playground.security.repository.PersonRepository;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Prepares a small, consistent dataset for the live demo so the operator
 * console always has journals to show. Only available when {@code app.demo.enabled}
 * is switched on (DEMO_MODE=true).
 */
@Service
public class DemoDataService {
    private final IncidentRepository incidentRepository;
    private final PersonRepository personRepository;

    public DemoDataService(IncidentRepository incidentRepository, PersonRepository personRepository) {
        this.incidentRepository = incidentRepository;
        this.personRepository = personRepository;
    }

    /** Wipes journals, seeds the sample data and returns the resulting counts. */
    @Transactional
    public Counts reset() {
        incidentRepository.deleteAll();
        personRepository.deleteAll();

        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);

        Person marina = personRepository.save(new Person(
                UUID.randomUUID().toString(), PersonStatus.PENDING, now.minus(Duration.ofHours(26)), null));
        marina.setDisplayName("Марина Сомова");
        marina.recordVisit(now.minus(Duration.ofHours(9)));
        marina.recordVisit(now.minus(Duration.ofMinutes(55)));
        marina.recordVisit(now.minus(Duration.ofMinutes(6)));

        Person petr = personRepository.save(new Person(
                UUID.randomUUID().toString(), PersonStatus.PENDING, now.minus(Duration.ofHours(13)), null));
        petr.setDisplayName("Пётр Кайдаков");
        petr.recordVisit(now.minus(Duration.ofMinutes(41)));

        Person trusted = personRepository.save(new Person(
                UUID.randomUUID().toString(), PersonStatus.TRUSTED, now.minus(Duration.ofDays(30)), null));
        trusted.setDisplayName("Анна Никитина (свой)");
        trusted.recordVisit(now.minus(Duration.ofHours(2)));

        marina = personRepository.save(marina);
        petr = personRepository.save(petr);
        Person trustedSaved = personRepository.save(trusted);

        saveIncident("CAR_ON_PLAYGROUND", now.minus(Duration.ofMinutes(12)),
                "car-7-red", 0.91, null);
        saveIncident("STRANGER_DETECTED", now.minus(Duration.ofMinutes(6)), "track-stranger-88",
                0.68, marina);
        saveIncident("VEHICLE", now.minus(Duration.ofHours(3)), "car-3-blue", 0.84, null);
        saveIncident("STRANGER_DETECTED", now.minus(Duration.ofMinutes(41)), "track-stranger-41",
                0.72, petr);
        saveIncident("STRANGER_DETECTED", now.minus(Duration.ofHours(26)), "track-stranger-1",
                0.59, trustedSaved);

        return new Counts(personRepository.count(), incidentRepository.count());
    }

    private void saveIncident(String type, OffsetDateTime occurredAt, String trackId,
            Double confidence, Person person) {
        incidentRepository.save(new Incident(
                UUID.randomUUID().toString(),
                type,
                occurredAt,
                defaultDescription(type),
                null,
                trackId,
                confidence,
                person));
    }

    private String defaultDescription(String type) {
        return switch (type) {
            case "CAR_ON_PLAYGROUND", "CAR_IN_ZONE", "VEHICLE_IN_ZONE", "VEHICLE" ->
                    "Тревога! Автомобиль на детской площадке";
            case "STRANGER", "UNKNOWN_PERSON", "STRANGER_DETECTED" ->
                    "Обнаружен незнакомый посетитель";
            default -> "Зарегистрировано событие: " + type;
        };
    }

    /** Resulting dataset size after a reset. */
    public record Counts(long persons, long incidents) {}
}
