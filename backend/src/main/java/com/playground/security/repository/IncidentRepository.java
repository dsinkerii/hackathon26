package com.playground.security.repository;

import com.playground.security.entity.Incident;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface IncidentRepository extends JpaRepository<Incident, String> {
    List<Incident> findAllByOrderByOccurredAtDesc();

    /** Связанные инциденты посетителя (свойство person.id через ассоциацию). */
    List<Incident> deleteByPersonId(String personId);

    Optional<Incident> findFirstByTrackIdAndTypeAndOccurredAtAfterOrderByOccurredAtDesc(
            String trackId, String type, OffsetDateTime occurredAt);

    /**
     * Fallback for CV events without a stable track ID: suppress a second event
     * of the same type inside the deduplication window.
     */
    Optional<Incident> findFirstByTypeAndOccurredAtAfterOrderByOccurredAtDesc(
            String type, OffsetDateTime occurredAt);
}
