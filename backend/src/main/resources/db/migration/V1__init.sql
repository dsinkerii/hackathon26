CREATE TABLE persons (
    id VARCHAR(36) PRIMARY KEY,
    display_name VARCHAR(200),
    status VARCHAR(24) NOT NULL,
    first_seen_at TIMESTAMP WITH TIME ZONE NOT NULL,
    last_seen_at TIMESTAMP WITH TIME ZONE NOT NULL,
    visit_count INTEGER NOT NULL DEFAULT 1,
    photo_url VARCHAR(1024),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_person_status CHECK (status IN ('PENDING', 'TRUSTED')),
    CONSTRAINT chk_person_visit_count CHECK (visit_count > 0)
);

CREATE INDEX idx_persons_status_first_seen
    ON persons (status, first_seen_at DESC);

CREATE TABLE incidents (
    id VARCHAR(36) PRIMARY KEY,
    type VARCHAR(64) NOT NULL,
    occurred_at TIMESTAMP WITH TIME ZONE NOT NULL,
    description VARCHAR(1000),
    snapshot_url VARCHAR(1024),
    track_id VARCHAR(200),
    confidence DOUBLE PRECISION,
    person_id VARCHAR(36),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_incidents_person
        FOREIGN KEY (person_id) REFERENCES persons (id) ON DELETE SET NULL,
    CONSTRAINT chk_incident_confidence
        CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1))
);

CREATE INDEX idx_incidents_occurred_at
    ON incidents (occurred_at DESC);

CREATE INDEX idx_incidents_track_type_time
    ON incidents (track_id, type, occurred_at DESC);
