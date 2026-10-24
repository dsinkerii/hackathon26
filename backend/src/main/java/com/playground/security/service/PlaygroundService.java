package com.playground.security.service;

import com.playground.security.common.ApiException;
import com.playground.security.config.AppProperties;
import com.playground.security.dto.IngestRequest;
import com.playground.security.entity.Incident;
import com.playground.security.entity.Person;
import com.playground.security.entity.PersonStatus;
import com.playground.security.media.MediaStorageService;
import com.playground.security.repository.IncidentRepository;
import com.playground.security.repository.PersonRepository;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PlaygroundService {
    private static final Set<String> STRANGER_TYPES =
            Set.of("STRANGER", "UNKNOWN_PERSON", "STRANGER_DETECTED");
    private final IncidentRepository incidentRepository;
    private final PersonRepository personRepository;
    private final MediaStorageService mediaStorage;
    private final AppProperties properties;

    public PlaygroundService(
            IncidentRepository incidentRepository,
            PersonRepository personRepository,
            MediaStorageService mediaStorage,
            AppProperties properties) {
        this.incidentRepository = incidentRepository;
        this.personRepository = personRepository;
        this.mediaStorage = mediaStorage;
        this.properties = properties;
    }

    @Transactional(readOnly = true)
    public List<Incident> incidents() {
        return incidentRepository.findAllByOrderByOccurredAtDesc();
    }

    @Transactional(readOnly = true)
    public List<Person> persons() {
        return personRepository.findAllByOrderByLastSeenAtDesc();
    }

    @Transactional
    public IngestResult ingest(IngestRequest request) {
        OffsetDateTime occurredAt = request.occurredAt().withOffsetSameInstant(ZoneOffset.UTC);
        String type = request.type().trim().toUpperCase();
        String trackId = request.trackId() == null || request.trackId().isBlank()
                ? null : request.trackId().trim();
        OffsetDateTime duplicateSince = occurredAt.minus(properties.ingest().deduplicationWindow());

        if (trackId != null) {
            var duplicate = incidentRepository
                    .findFirstByTrackIdAndTypeAndOccurredAtAfterOrderByOccurredAtDesc(
                            trackId, type, duplicateSince);
            if (duplicate.isPresent()) {
                return new IngestResult(duplicate.get(), false);
            }
        }

        String snapshotUrl = mediaStorage.saveJpeg(request.snapshotBase64(), "snapshots");
        Person person = null;
        if (STRANGER_TYPES.contains(type)) {
            if (request.personId() != null && !request.personId().isBlank()) {
                person = personRepository.findById(request.personId())
                        .orElseThrow(() -> new ApiException(
                                HttpStatus.NOT_FOUND, "PERSON_NOT_FOUND", "Person was not found."));
                person.recordVisit(occurredAt);
            } else {
                String faceUrl = mediaStorage.saveJpeg(request.faceSnapshotBase64(), "faces");
                person = personRepository.save(new Person(
                        UUID.randomUUID().toString(),
                        PersonStatus.PENDING,
                        occurredAt,
                        faceUrl));
            }
        }

        String description = request.description();
        if (description == null || description.isBlank()) {
            description = defaultDescription(type);
        }
        Incident incident = new Incident(
                UUID.randomUUID().toString(),
                type,
                occurredAt,
                description,
                snapshotUrl,
                trackId,
                request.confidence(),
                person);
        return new IngestResult(incidentRepository.save(incident), true);
    }

    @Transactional
    public void confirmPerson(String id) {
        Person person = personRepository.findById(id)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND, "PERSON_NOT_FOUND", "Person was not found."));
        person.confirm();
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

    public record IngestResult(Incident incident, boolean created) {}
}
