-- =============================================================
--  TELEMETRY & UX DATABASE  –  DDL COMPLETO  (Parte B)
--  Proyecto Bases de Datos  |  Javeriana 2026
--  Orden de creación respeta todas las dependencias FK
-- =============================================================

-- -------------------------------------------------------------
-- 0. LIMPIEZA (útil para re-ejecutar en desarrollo)
-- -------------------------------------------------------------
DROP TABLE IF EXISTS
    ux_response_item, ux_response, ux_item, ux_instrument,
    telemetry_event, game_participant, game,
    sector, map, episode,
    player, "user",
    telemetry_staging, etl_error_log
CASCADE;


-- =============================================================
-- 1. TABLAS CORE  (fiel al diagrama ER Entrega A)
-- =============================================================

CREATE TABLE "user" (
    user_id       SERIAL        PRIMARY KEY,
    username      VARCHAR(64)   NOT NULL UNIQUE,
    email         VARCHAR(128)  UNIQUE,
    consent_given BOOLEAN       NOT NULL DEFAULT FALSE,
    consent_date  TIMESTAMP,
    created_at    TIMESTAMP     NOT NULL DEFAULT NOW()
);

CREATE TABLE player (
    player_id  SERIAL       PRIMARY KEY,
    user_id    INT,
    nickname   VARCHAR(64)  NOT NULL,
    created_at TIMESTAMP    NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_player_user
        FOREIGN KEY (user_id)
        REFERENCES "user"(user_id)
        ON DELETE SET NULL
);

CREATE TABLE episode (
    episode_id  SERIAL      PRIMARY KEY,
    name        VARCHAR(64) NOT NULL,
    description TEXT
);

CREATE TABLE map (
    map_id     SERIAL      PRIMARY KEY,
    episode_id INT         NOT NULL,
    map_code   VARCHAR(16) NOT NULL,
    map_name   VARCHAR(64) NOT NULL,

    CONSTRAINT fk_map_episode
        FOREIGN KEY (episode_id)
        REFERENCES episode(episode_id)
        ON DELETE CASCADE
);

CREATE TABLE sector (
    sector_id   SERIAL      PRIMARY KEY,
    map_id      INT         NOT NULL,
    sector_name VARCHAR(64),

    CONSTRAINT fk_sector_map
        FOREIGN KEY (map_id)
        REFERENCES map(map_id)
        ON DELETE CASCADE
);

CREATE TABLE game (
    game_id    SERIAL      PRIMARY KEY,
    map_id     INT         NOT NULL,
    -- player_id: jugador principal de la sesión, según diagrama ER (relación 'plays').
    -- game_participant cubre sesiones multi-jugador; este FK refleja el diagrama.
    player_id  INT         NOT NULL,
    start_time TIMESTAMP   NOT NULL,
    end_time   TIMESTAMP,
    difficulty VARCHAR(16) NOT NULL,

    CONSTRAINT fk_game_map
        FOREIGN KEY (map_id)
        REFERENCES map(map_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_game_player
        FOREIGN KEY (player_id)
        REFERENCES player(player_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_game_difficulty
        CHECK (difficulty IN ('easy', 'medium', 'hard', 'nightmare'))
);

CREATE TABLE game_participant (
    game_id   INT          NOT NULL,
    player_id INT          NOT NULL,
    role      VARCHAR(32),
    score     INT          DEFAULT 0,

    PRIMARY KEY (game_id, player_id),

    CONSTRAINT fk_gp_game
        FOREIGN KEY (game_id)
        REFERENCES game(game_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_gp_player
        FOREIGN KEY (player_id)
        REFERENCES player(player_id)
        ON DELETE CASCADE
);

CREATE TABLE telemetry_event (
    -- El diagrama marca 'int'; se usa BIGSERIAL por el volumen esperado (≥20k filas).
    event_id  BIGSERIAL  PRIMARY KEY,
    game_id   INT        NOT NULL,
    -- player_id no aparece explícitamente en el diagrama de TELEMETRY_EVENT,
    -- pero es necesario para las consultas de trayectoria y se infiere del game.
    -- Se incluye por completitud y se documenta aquí.
    player_id INT        NOT NULL,
    sector_id INT        NOT NULL,   -- NOT NULL: el diagrama no lo marca nullable
    tic       INT        NOT NULL,
    timestamp TIMESTAMP  NOT NULL,

    x         FLOAT      NOT NULL,
    y         FLOAT      NOT NULL,
    z         FLOAT      NOT NULL,

    angle     FLOAT      NOT NULL,
    momx      FLOAT      NOT NULL,
    momy      FLOAT      NOT NULL,

    health    INT,
    armor     INT,
    ammo      INT,

    CONSTRAINT fk_te_game
        FOREIGN KEY (game_id)
        REFERENCES game(game_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_te_player
        FOREIGN KEY (player_id)
        REFERENCES player(player_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_te_sector
        FOREIGN KEY (sector_id)
        REFERENCES sector(sector_id)
        ON DELETE RESTRICT,

    -- Garantiza que no haya dos registros del mismo jugador en el mismo tic/game
    CONSTRAINT uq_telemetry_event
        UNIQUE (game_id, tic, player_id),

    CONSTRAINT chk_health
        CHECK (health IS NULL OR (health BETWEEN 0 AND 200)),

    CONSTRAINT chk_armor
        CHECK (armor  IS NULL OR (armor  BETWEEN 0 AND 200))
);

CREATE TABLE ux_instrument (
    instrument_id SERIAL      PRIMARY KEY,
    name          VARCHAR(32) NOT NULL UNIQUE,
    description   TEXT,
    version       VARCHAR(16) NOT NULL,

    CONSTRAINT chk_instrument_name
        CHECK (name IN ('PENS', 'GUESS', 'BANGS'))
);

CREATE TABLE ux_item (
    item_id       SERIAL      PRIMARY KEY,
    instrument_id INT         NOT NULL,
    question_text TEXT        NOT NULL,
    response_type VARCHAR(32) NOT NULL,

    CONSTRAINT fk_item_instrument
        FOREIGN KEY (instrument_id)
        REFERENCES ux_instrument(instrument_id)
        ON DELETE CASCADE,

    CONSTRAINT chk_response_type
        CHECK (response_type IN ('likert', 'open', 'binary'))
);

CREATE TABLE ux_response (
    response_id   SERIAL    PRIMARY KEY,
    user_id       INT       NOT NULL,
    instrument_id INT       NOT NULL,
    game_id       INT       NOT NULL,
    submitted_at  TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_response_user
        FOREIGN KEY (user_id)
        REFERENCES "user"(user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_response_instrument
        FOREIGN KEY (instrument_id)
        REFERENCES ux_instrument(instrument_id),

    CONSTRAINT fk_response_game
        FOREIGN KEY (game_id)
        REFERENCES game(game_id)
        ON DELETE CASCADE
);

CREATE TABLE ux_response_item (
    response_item_id SERIAL       PRIMARY KEY,
    response_id      INT          NOT NULL,
    item_id          INT          NOT NULL,
    response_value   VARCHAR(256) NOT NULL,

    CONSTRAINT fk_response_item_response
        FOREIGN KEY (response_id)
        REFERENCES ux_response(response_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_response_item_item
        FOREIGN KEY (item_id)
        REFERENCES ux_item(item_id)
);


-- =============================================================
-- 2. TABLAS ETL  (nuevas en Parte B)
-- =============================================================

-- 2a. Staging: todos los campos como TEXT, sin restricciones.
--     Se carga con COPY directamente desde el TSV del motor.
CREATE TABLE telemetry_staging (
    raw_id      BIGSERIAL   PRIMARY KEY,
    game_id     TEXT,
    player_id   TEXT,
    sector_id   TEXT,
    tic         TEXT,
    ts          TEXT,       -- columna 'timestamp' como texto
    x           TEXT,
    y           TEXT,
    z           TEXT,
    angle       TEXT,
    momx        TEXT,
    momy        TEXT,
    health      TEXT,
    armor       TEXT,
    ammo        TEXT,
    loaded_at   TIMESTAMP   NOT NULL DEFAULT NOW()
);

-- 2b. Log de errores: filas rechazadas durante la transformación ETL.
CREATE TABLE etl_error_log (
    error_id    BIGSERIAL   PRIMARY KEY,
    raw_id      BIGINT      NOT NULL,   -- referencia al raw_id en staging
    error_msg   TEXT        NOT NULL,
    logged_at   TIMESTAMP   NOT NULL DEFAULT NOW()
);


-- =============================================================
-- 3. ÍNDICES  (requeridos en Parte C, declarados aquí)
-- =============================================================

-- Consultas de trayectoria: ordenar eventos de un jugador en un game por tic
CREATE INDEX idx_te_game_player_tic
    ON telemetry_event (game_id, player_id, tic);

-- Consultas de hotspot: agrupar por sector dentro de un mapa/episodio
CREATE INDEX idx_te_sector
    ON telemetry_event (sector_id);

-- Co-presencia: buscar todos los eventos de un tic dado dentro de un game
CREATE INDEX idx_te_game_tic
    ON telemetry_event (game_id, tic);

-- Participantes de un juego (join frecuente con telemetry_event)
CREATE INDEX idx_gp_player
    ON game_participant (player_id, game_id);

-- Respuestas UX por usuario
CREATE INDEX idx_ux_response_user
    ON ux_response (user_id);


-- =============================================================
-- Fin del script
-- =============================================================
