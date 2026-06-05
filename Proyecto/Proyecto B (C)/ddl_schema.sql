-- ============================================================
-- DDL: Telemetry & UX Database for Chocolate-Doom Research
-- PostgreSQL
-- Orden topológico: tablas sin FK primero
-- ============================================================

-- Extensiones opcionales (bonus)
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- CREATE EXTENSION IF NOT EXISTS postgis;

-- ------------------------------------------------------------
-- 1. EPISODE
-- ------------------------------------------------------------
CREATE TABLE episode (
    episode_id   SERIAL       PRIMARY KEY,
    name         VARCHAR(100) NOT NULL,
    description  TEXT
);

-- ------------------------------------------------------------
-- 2. MAP
-- ------------------------------------------------------------
CREATE TABLE map (
    map_id    SERIAL       PRIMARY KEY,
    episode_id INT          NOT NULL REFERENCES episode(episode_id),
    map_code  VARCHAR(20)  NOT NULL,           -- e.g. 'E1M1'
    map_name  VARCHAR(100),
    UNIQUE (episode_id, map_code)
);

-- ------------------------------------------------------------
-- 3. SECTOR
-- ------------------------------------------------------------
CREATE TABLE sector (
    sector_id   INT          NOT NULL,         -- ID nativo del motor
    map_id      INT          NOT NULL REFERENCES map(map_id),
    sector_name VARCHAR(100),
    PRIMARY KEY (sector_id, map_id)
);

-- ------------------------------------------------------------
-- 4. USER (voluntario/investigado)
-- ------------------------------------------------------------
CREATE TABLE "user" (
    user_id       SERIAL       PRIMARY KEY,
    username      VARCHAR(100) NOT NULL UNIQUE,
    email         VARCHAR(255) NOT NULL UNIQUE,
    consent_given BOOLEAN      NOT NULL DEFAULT FALSE,
    consent_date  TIMESTAMP,
    created_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
    -- Demographics
    age           SMALLINT     CHECK (age > 0 AND age < 120),
    gender        VARCHAR(30),
    experience    VARCHAR(30)  CHECK (experience IN ('none','low','medium','high'))
);

-- ------------------------------------------------------------
-- 5. PLAYER (identidad en el juego)
-- ------------------------------------------------------------
CREATE TABLE player (
    player_id  SERIAL       PRIMARY KEY,
    user_id    INT          NOT NULL REFERENCES "user"(user_id),
    nickname   VARCHAR(100) NOT NULL,
    created_at TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- 6. GAME (sesión de juego)
-- ------------------------------------------------------------
CREATE TABLE game (
    game_id    SERIAL       PRIMARY KEY,
    map_id     INT          NOT NULL REFERENCES map(map_id),
    player_id  INT          NOT NULL REFERENCES player(player_id),
    start_time TIMESTAMP    NOT NULL,
    end_time   TIMESTAMP,
    difficulty VARCHAR(20)  CHECK (difficulty IN ('itytd','hntr','hmp','uv','nm')),
    CONSTRAINT chk_game_times CHECK (end_time IS NULL OR end_time >= start_time)
);

-- ------------------------------------------------------------
-- 7. TELEMETRY_EVENT (registro por tic)
-- ------------------------------------------------------------
CREATE TABLE telemetry_event (
    event_id   BIGSERIAL    PRIMARY KEY,
    game_id    INT          NOT NULL REFERENCES game(game_id),
    sector_id  INT          NOT NULL,
    map_id     INT          NOT NULL,
    tic        INT          NOT NULL,
    ts         TIMESTAMP    NOT NULL,
    x          FLOAT        NOT NULL,
    y          FLOAT        NOT NULL,
    z          FLOAT,
    angle      FLOAT,                          -- grados (0–360)
    momx       FLOAT,
    momy       FLOAT,
    health     INT,
    armor      INT,
    ammo       INT,
    FOREIGN KEY (sector_id, map_id) REFERENCES sector(sector_id, map_id),
    UNIQUE (game_id, tic)                      -- deduplicación
);

-- ------------------------------------------------------------
-- 8. UX_INSTRUMENT
-- ------------------------------------------------------------
CREATE TABLE ux_instrument (
    instrument_id SERIAL       PRIMARY KEY,
    name          VARCHAR(50)  NOT NULL UNIQUE, -- 'PENS', 'GUESS', 'BANGS'
    description   TEXT,
    version       VARCHAR(20)
);

-- ------------------------------------------------------------
-- 9. UX_ITEM (preguntas del instrumento)
-- ------------------------------------------------------------
CREATE TABLE ux_item (
    item_id       SERIAL       PRIMARY KEY,
    instrument_id INT          NOT NULL REFERENCES ux_instrument(instrument_id),
    question_text TEXT         NOT NULL,
    response_type VARCHAR(30)  NOT NULL        -- 'likert5', 'likert7', 'open'
);

-- ------------------------------------------------------------
-- 10. UX_RESPONSE (encabezado de respuesta de un usuario)
-- ------------------------------------------------------------
CREATE TABLE ux_response (
    response_id   SERIAL    PRIMARY KEY,
    user_id       INT       NOT NULL REFERENCES "user"(user_id),
    instrument_id INT       NOT NULL REFERENCES ux_instrument(instrument_id),
    game_id       INT       NOT NULL REFERENCES game(game_id),
    submitted_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- 11. UX_RESPONSE_ITEM (respuesta a cada pregunta)
-- ------------------------------------------------------------
CREATE TABLE ux_response_item (
    response_item_id SERIAL       PRIMARY KEY,
    response_id      INT          NOT NULL REFERENCES ux_response(response_id),
    item_id          INT          NOT NULL REFERENCES ux_item(item_id),
    response_value   VARCHAR(255) NOT NULL,
    UNIQUE (response_id, item_id)
);

-- ============================================================
-- ÍNDICES (sugeridos por el enunciado + extras útiles)
-- ============================================================

-- Consultas por juego/jugador/tic (query plan principal)
CREATE INDEX idx_te_game_tic      ON telemetry_event (game_id, tic);

-- Consultas por ubicación en el mapa
CREATE INDEX idx_te_map_sector    ON telemetry_event (map_id, sector_id);

-- Índice espacial 2D para cálculos de proximidad
CREATE INDEX idx_te_pos           ON telemetry_event USING gist (
    point(x, y)
);

-- Participación por jugador
CREATE INDEX idx_game_player      ON game (player_id, game_id);

-- ============================================================
-- STAGING TABLE (ETL - carga cruda del TSV)
-- ============================================================

CREATE TABLE staging_telemetry (
    raw_id      BIGSERIAL PRIMARY KEY,
    ts_raw      TEXT,
    tic_raw     TEXT,
    x_raw       TEXT,
    y_raw       TEXT,
    sector_raw  TEXT,
    angle_raw   TEXT,
    momx_raw    TEXT,
    momy_raw    TEXT,
    ammo_raw    TEXT,
    load_time   TIMESTAMP NOT NULL DEFAULT NOW(),
    game_id     INT,          -- se asigna antes o durante el ETL
    is_valid    BOOLEAN,
    error_msg   TEXT
);

-- ============================================================
-- ERROR LOG TABLE (registros rechazados en ETL)
-- ============================================================

CREATE TABLE etl_error_log (
    error_id   BIGSERIAL PRIMARY KEY,
    raw_id     BIGINT    REFERENCES staging_telemetry(raw_id),
    error_msg  TEXT,
    logged_at  TIMESTAMP NOT NULL DEFAULT NOW()
);
