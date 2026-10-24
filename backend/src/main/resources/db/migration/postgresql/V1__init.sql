-- 1. Белый список (жители, обслуживающий персонал)
CREATE TABLE person_whitelist (
    id             BIGSERIAL    PRIMARY KEY,
    full_name      VARCHAR(150) NOT NULL,
    face_embedding TEXT         NOT NULL,
    photo_url      VARCHAR(500) NOT NULL,
    visit_count    INT          NOT NULL DEFAULT 0,
    status         VARCHAR(20)  NOT NULL DEFAULT 'TRUSTED'
                   CHECK (status IN ('TRUSTED', 'PENDING')),
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- 2. Незнакомцы (кандидаты на белый список)
CREATE TABLE stranger (
    id                BIGSERIAL    PRIMARY KEY,
    face_embedding    TEXT         NOT NULL,
    best_snapshot_url VARCHAR(500) NOT NULL,
    first_seen        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    last_seen         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    visit_count       INT          NOT NULL DEFAULT 0,
    whitelist_id      BIGINT       REFERENCES person_whitelist(id) ON DELETE SET NULL
);

-- 3. Инциденты (журнал нарушений)
CREATE TABLE incident (
    id           BIGSERIAL    PRIMARY KEY,
    type         VARCHAR(50)  NOT NULL
                 CHECK (type IN ('CAR_ON_PLAYGROUND', 'STRANGER_DETECTED')),
    occurred_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    description  VARCHAR(255) NOT NULL,
    snapshot_url VARCHAR(500),
    track_id     BIGINT,
    confidence   REAL,
    stranger_id  BIGINT       REFERENCES stranger(id) ON DELETE SET NULL,
    processed    BOOLEAN      NOT NULL DEFAULT FALSE,
    processed_at TIMESTAMPTZ,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- 4. Настройки системы
CREATE TABLE app_settings (
    key        VARCHAR(100) PRIMARY KEY,
    value      TEXT         NOT NULL,
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_incident_occurred_at ON incident (occurred_at DESC);
CREATE INDEX idx_incident_type        ON incident (type);
CREATE INDEX idx_incident_processed   ON incident (processed);
CREATE INDEX idx_incident_track_id    ON incident (track_id);
CREATE INDEX idx_stranger_visit_count ON stranger (visit_count DESC);
CREATE INDEX idx_whitelist_status     ON person_whitelist (status);