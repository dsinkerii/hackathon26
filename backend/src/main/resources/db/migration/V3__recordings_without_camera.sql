-- Recordings may exist without an associated camera; such entries form a
-- hidden category that is only visible to administrators.
ALTER TABLE recordings DROP CONSTRAINT fk_recordings_camera;
ALTER TABLE recordings ALTER COLUMN camera_id DROP NOT NULL;
ALTER TABLE recordings ADD CONSTRAINT fk_recordings_camera
    FOREIGN KEY (camera_id) REFERENCES cameras (id) ON DELETE RESTRICT;
