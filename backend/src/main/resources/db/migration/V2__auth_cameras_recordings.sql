CREATE TABLE admin_users (
    id VARCHAR(36) PRIMARY KEY,
    username VARCHAR(80) NOT NULL UNIQUE,
    password_hash VARCHAR(100) NOT NULL,
    role VARCHAR(24) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_admin_user_role CHECK (role IN ('ADMIN', 'OPERATOR'))
);

CREATE TABLE cameras (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(120) NOT NULL UNIQUE,
    location VARCHAR(300),
    stream_url VARCHAR(2048),
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE recordings (
    id VARCHAR(36) PRIMARY KEY,
    camera_id VARCHAR(36) NOT NULL,
    title VARCHAR(200) NOT NULL,
    event_type VARCHAR(64),
    recorded_at TIMESTAMP WITH TIME ZONE NOT NULL,
    duration_seconds INTEGER,
    video_url VARCHAR(2048) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_recordings_camera
        FOREIGN KEY (camera_id) REFERENCES cameras (id) ON DELETE RESTRICT,
    CONSTRAINT chk_recordings_duration CHECK (
        duration_seconds IS NULL OR duration_seconds > 0
    )
);

CREATE INDEX idx_recordings_camera_time
    ON recordings (camera_id, recorded_at DESC);

CREATE INDEX idx_recordings_time
    ON recordings (recorded_at DESC);
