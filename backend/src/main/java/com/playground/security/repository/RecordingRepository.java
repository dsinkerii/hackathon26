package com.playground.security.repository;

import com.playground.security.entity.Recording;
import java.time.OffsetDateTime;
import java.util.List;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface RecordingRepository extends JpaRepository<Recording, String>,
        JpaSpecificationExecutor<Recording> {
    @Override
    @EntityGraph(attributePaths = "camera")
    List<Recording> findAll(Specification<Recording> specification, org.springframework.data.domain.Sort sort);

    static Specification<Recording> byFilters(
            String cameraId,
            Boolean withoutCamera,
            OffsetDateTime from,
            OffsetDateTime to) {
        return (root, query, builder) -> {
            var filters = new java.util.ArrayList<jakarta.persistence.criteria.Predicate>();
            if (Boolean.TRUE.equals(withoutCamera)) {
                filters.add(builder.isNull(root.get("camera")));
            } else if (cameraId != null && !cameraId.isBlank()) {
                filters.add(builder.equal(root.get("camera").get("id"), cameraId));
            } else {
                // The no-camera category is separate: the default list only
                // shows recordings bound to a camera, even for administrators.
                filters.add(root.get("camera").isNotNull());
            }
            if (from != null) {
                filters.add(builder.greaterThanOrEqualTo(root.get("recordedAt"), from));
            }
            if (to != null) {
                filters.add(builder.lessThan(root.get("recordedAt"), to));
            }
            return builder.and(filters.toArray(jakarta.persistence.criteria.Predicate[]::new));
        };
    }
}
