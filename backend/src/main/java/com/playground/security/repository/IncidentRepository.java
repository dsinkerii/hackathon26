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
}
