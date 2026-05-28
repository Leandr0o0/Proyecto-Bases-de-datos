-- ============================================================
-- staging → validación → telemetry_event
--
--  Nota: health, armor y ammo NO están en el TSV del motor;
--        se insertan como NULL (campos opcionales en el esquema).
--
--  Los campos del TSV llegan con espacios de relleno (ej: " 471").
--  Todos los regex de validación usan trim() antes de comparar.
-- ============================================================

-- ── STAGING TABLE ────────────────────────────────────────────
DROP TABLE IF EXISTS staging_telemetry CASCADE;

CREATE TABLE staging_telemetry (
    raw_id     BIGSERIAL    PRIMARY KEY,
    ts         TEXT,            -- col1: timestamp como texto
    tic        TEXT,            -- col2: número de tic
    x          TEXT,            -- col3: posición X
    y          TEXT,            -- col4: posición Y
    z          TEXT,            -- col5: altura Z
    angle      TEXT,            -- col6: ángulo (0-360°)
    momx       TEXT,            -- col7: momentum X
    momy       TEXT,            -- col8: momentum Y
    sector_raw TEXT,            -- col9: sector 0-based del TSV
    -- Metadatos ETL (asignar antes de llamar etl_load_telemetry)
    game_id    INT,
    player_id  INT,
    loaded_at  TIMESTAMP    NOT NULL DEFAULT NOW(),
    status     VARCHAR(16)  NOT NULL DEFAULT 'pending'
    -- 'pending' | 'ok' | 'duplicate' | 'invalid'
);

-- ── ERROR LOG ────────────────────────────────────────────────
DROP TABLE IF EXISTS etl_error_log;

CREATE TABLE etl_error_log (
    error_id  BIGSERIAL  PRIMARY KEY,
    raw_id    BIGINT,
    reason    TEXT,
    raw_data  TEXT,
    logged_at TIMESTAMP  NOT NULL DEFAULT NOW()
);

-- ============================================================
--  FUNCIÓN ETL: staging → telemetry_event
--
--  Flujo:
--    1. Cargar TSV con \copy → staging_telemetry
--    2. UPDATE staging SET game_id=X, player_id=Y
--    3. SELECT * FROM etl_load_telemetry()
--
--  sector_raw es 0-based → se resuelve al sector_id real
--  buscando el N-ésimo sector del mapa de la partida.
-- ============================================================
CREATE OR REPLACE FUNCTION etl_load_telemetry()
RETURNS TABLE(
    inserted   BIGINT,
    duplicates BIGINT,
    invalid    BIGINT
) AS $$
DECLARE
    v_inserted   BIGINT := 0;
    v_duplicates BIGINT := 0;
    v_invalid    BIGINT := 0;
BEGIN
    -- 1. Validar campos numéricos (trim() para espacios del TSV)
    UPDATE staging_telemetry SET status = 'invalid'
    WHERE status = 'pending'
      AND (
          game_id   IS NULL OR
          player_id IS NULL OR
          tic       IS NULL OR trim(tic)   !~ '^-?[\d]+$'  OR
          ts        IS NULL OR
          x         IS NULL OR trim(x)     !~ '^-?[\d.]+$' OR
          y         IS NULL OR trim(y)     !~ '^-?[\d.]+$' OR
          z         IS NULL OR trim(z)     !~ '^-?[\d.]+$' OR
          angle     IS NULL OR trim(angle) !~ '^-?[\d.]+$' OR
          momx      IS NULL OR trim(momx)  !~ '^-?[\d.]+$' OR
          momy      IS NULL OR trim(momy)  !~ '^-?[\d.]+$'
      );

    INSERT INTO etl_error_log (raw_id, reason, raw_data)
    SELECT raw_id, 'Missing or non-numeric required field',
           concat_ws('|', game_id::TEXT, player_id::TEXT, tic, ts, x, y, z)
    FROM staging_telemetry WHERE status = 'invalid';
    GET DIAGNOSTICS v_invalid = ROW_COUNT;

    -- 2. Validar que game_id/player_id existen en la tabla game
    UPDATE staging_telemetry SET status = 'invalid'
    WHERE status = 'pending'
      AND NOT EXISTS (
          SELECT 1 FROM game g
          WHERE g.game_id   = staging_telemetry.game_id
            AND g.player_id = staging_telemetry.player_id
      );

    INSERT INTO etl_error_log (raw_id, reason, raw_data)
    SELECT raw_id, 'game_id/player_id combination does not exist',
           game_id || '/' || player_id
    FROM staging_telemetry
    WHERE status = 'invalid'
      AND raw_id NOT IN (SELECT raw_id FROM etl_error_log);

    -- 3. Detectar duplicados vs telemetry_event existente
    UPDATE staging_telemetry s SET status = 'duplicate'
    WHERE s.status = 'pending'
      AND EXISTS (
          SELECT 1 FROM telemetry_event te
          WHERE te.game_id   = s.game_id
            AND te.player_id = s.player_id
            AND te.tic       = trim(s.tic)::INT
      );
    GET DIAGNOSTICS v_duplicates = ROW_COUNT;

    -- 4. Insertar filas válidas en telemetry_event
    --    sector_raw 0-based → N-ésimo sector del mapa de la partida
    INSERT INTO telemetry_event
        (game_id, player_id, sector_id, tic, timestamp,
         x, y, z, angle, momx, momy,
         health, armor, ammo)
    SELECT
        s.game_id,
        s.player_id,
        (SELECT sec.sector_id
         FROM sector sec
         JOIN game g2 ON g2.game_id = s.game_id
         WHERE sec.map_id = g2.map_id
         ORDER BY sec.sector_id
         OFFSET trim(s.sector_raw)::INT LIMIT 1),
        trim(s.tic)::INT,
        trim(s.ts)::TIMESTAMP,
        trim(s.x)::FLOAT,
        trim(s.y)::FLOAT,
        trim(s.z)::FLOAT,
        trim(s.angle)::FLOAT,
        trim(s.momx)::FLOAT,
        trim(s.momy)::FLOAT,
        NULL,   -- health: no presente en el TSV del motor
        NULL,   -- armor:  no presente en el TSV del motor
        NULL    -- ammo:   no presente en el TSV del motor
    FROM staging_telemetry s
    WHERE s.status = 'pending'
    ON CONFLICT (game_id, tic, player_id) DO NOTHING;
    GET DIAGNOSTICS v_inserted = ROW_COUNT;

    -- 5. Marcar filas restantes como procesadas
    UPDATE staging_telemetry SET status = 'ok'
    WHERE status = 'pending';

    RETURN QUERY SELECT v_inserted, v_duplicates, v_invalid;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
--  VISTA DE RESUMEN ETL
-- ============================================================
CREATE OR REPLACE VIEW v_etl_summary AS
SELECT
    status,
    COUNT(*)       AS total_rows,
    MIN(loaded_at) AS first_load,
    MAX(loaded_at) AS last_load
FROM staging_telemetry
GROUP BY status;

