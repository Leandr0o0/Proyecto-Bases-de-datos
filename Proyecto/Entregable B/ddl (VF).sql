-- Database: doom_telemetry

-- DROP DATABASE IF EXISTS doom_telemetry;

CREATE DATABASE doom_telemetry
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1
    IS_TEMPLATE = False;

-- Table: public.episode

-- DROP TABLE IF EXISTS public.episode;

CREATE TABLE IF NOT EXISTS public.episode
(
    episode_id integer NOT NULL DEFAULT nextval('episode_episode_id_seq'::regclass),
    name character varying(64) COLLATE pg_catalog."default" NOT NULL,
    description text COLLATE pg_catalog."default",
    CONSTRAINT episode_pkey PRIMARY KEY (episode_id)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.episode
    OWNER to postgres;

-- Table: public.etl_error_log

-- DROP TABLE IF EXISTS public.etl_error_log;

CREATE TABLE IF NOT EXISTS public.etl_error_log
(
    error_id integer NOT NULL DEFAULT nextval('etl_error_log_error_id_seq'::regclass),
    raw_data text COLLATE pg_catalog."default",
    error_msg text COLLATE pg_catalog."default",
    logged_at timestamp without time zone DEFAULT now(),
    raw_id bigint,
    CONSTRAINT etl_error_log_pkey PRIMARY KEY (error_id)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.etl_error_log
    OWNER to postgres;

-- Table: public.game

-- DROP TABLE IF EXISTS public.game;

CREATE TABLE IF NOT EXISTS public.game
(
    game_id integer NOT NULL DEFAULT nextval('game_game_id_seq'::regclass),
    map_id integer NOT NULL,
    player_id integer NOT NULL,
    start_time timestamp without time zone NOT NULL,
    end_time timestamp without time zone,
    difficulty character varying(16) COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT game_pkey PRIMARY KEY (game_id),
    CONSTRAINT fk_game_map FOREIGN KEY (map_id)
        REFERENCES public.map (map_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT fk_game_player FOREIGN KEY (player_id)
        REFERENCES public.player (player_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE RESTRICT,
    CONSTRAINT chk_game_difficulty CHECK (difficulty::text = ANY (ARRAY['easy'::character varying, 'medium'::character varying, 'hard'::character varying, 'nightmare'::character varying]::text[]))
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.game
    OWNER to postgres;

-- Table: public.map

-- DROP TABLE IF EXISTS public.map;

CREATE TABLE IF NOT EXISTS public.map
(
    map_id integer NOT NULL DEFAULT nextval('map_map_id_seq'::regclass),
    episode_id integer NOT NULL,
    map_code character varying(16) COLLATE pg_catalog."default" NOT NULL,
    map_name character varying(64) COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT map_pkey PRIMARY KEY (map_id),
    CONSTRAINT fk_map_episode FOREIGN KEY (episode_id)
        REFERENCES public.episode (episode_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE CASCADE
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.map
    OWNER to postgres;

-- Table: public.player

-- DROP TABLE IF EXISTS public.player;

CREATE TABLE IF NOT EXISTS public.player
(
    player_id integer NOT NULL DEFAULT nextval('player_player_id_seq'::regclass),
    user_id integer,
    nickname character varying(64) COLLATE pg_catalog."default" NOT NULL,
    created_at timestamp without time zone NOT NULL DEFAULT now(),
    CONSTRAINT player_pkey PRIMARY KEY (player_id),
    CONSTRAINT fk_player_user FOREIGN KEY (user_id)
        REFERENCES public."user" (user_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE CASCADE
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.player
    OWNER to postgres;

-- Table: public.sector

-- DROP TABLE IF EXISTS public.sector;

CREATE TABLE IF NOT EXISTS public.sector
(
    sector_id integer NOT NULL DEFAULT nextval('sector_sector_id_seq'::regclass),
    map_id integer NOT NULL,
    sector_name character varying(64) COLLATE pg_catalog."default",
    CONSTRAINT sector_pkey PRIMARY KEY (sector_id),
    CONSTRAINT fk_sector_map FOREIGN KEY (map_id)
        REFERENCES public.map (map_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE CASCADE
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.sector
    OWNER to postgres;

-- Table: public.staging_telemetry

-- DROP TABLE IF EXISTS public.staging_telemetry;

CREATE TABLE IF NOT EXISTS public.staging_telemetry
(
    raw_game_id text COLLATE pg_catalog."default",
    raw_sector_id text COLLATE pg_catalog."default",
    raw_tic text COLLATE pg_catalog."default",
    raw_timestamp text COLLATE pg_catalog."default",
    raw_x text COLLATE pg_catalog."default",
    raw_y text COLLATE pg_catalog."default",
    raw_z text COLLATE pg_catalog."default",
    raw_angle text COLLATE pg_catalog."default",
    raw_momx text COLLATE pg_catalog."default",
    raw_momy text COLLATE pg_catalog."default",
    raw_health text COLLATE pg_catalog."default",
    raw_armor text COLLATE pg_catalog."default",
    raw_ammo text COLLATE pg_catalog."default",
    loaded_at timestamp without time zone DEFAULT now(),
    game_id integer,
    player_id integer,
    status character varying(16) COLLATE pg_catalog."default" NOT NULL DEFAULT 'pending'::character varying,
    CONSTRAINT chk_staging_status CHECK (status::text = ANY (ARRAY['pending'::character varying, 'ok'::character varying, 'duplicate'::character varying, 'invalid'::character varying]::text[]))
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.staging_telemetry
    OWNER to postgres;

-- Table: public.telemetry_event

-- DROP TABLE IF EXISTS public.telemetry_event;

CREATE TABLE IF NOT EXISTS public.telemetry_event
(
    event_id bigint NOT NULL DEFAULT nextval('telemetry_event_event_id_seq'::regclass),
    game_id integer NOT NULL,
    sector_id integer,
    tic integer NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    x double precision NOT NULL,
    y double precision NOT NULL,
    z double precision NOT NULL,
    angle double precision NOT NULL,
    momx double precision NOT NULL,
    momy double precision NOT NULL,
    health integer,
    armor integer,
    ammo integer,
    CONSTRAINT telemetry_event_pkey PRIMARY KEY (event_id),
    CONSTRAINT uq_telemetry_event UNIQUE (game_id, tic),
    CONSTRAINT fk_te_game FOREIGN KEY (game_id)
        REFERENCES public.game (game_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE CASCADE,
    CONSTRAINT fk_te_sector FOREIGN KEY (sector_id)
        REFERENCES public.sector (sector_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT chk_health CHECK (health IS NULL OR health >= 0 AND health <= 200),
    CONSTRAINT chk_armor CHECK (armor IS NULL OR armor >= 0 AND armor <= 200)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.telemetry_event
    OWNER to postgres;

-- Table: public.user

-- DROP TABLE IF EXISTS public."user";

CREATE TABLE IF NOT EXISTS public."user"
(
    user_id integer NOT NULL DEFAULT nextval('user_user_id_seq'::regclass),
    username character varying(64) COLLATE pg_catalog."default" NOT NULL,
    email character varying(128) COLLATE pg_catalog."default",
    consent_given boolean NOT NULL DEFAULT false,
    consent_date timestamp without time zone,
    created_at timestamp without time zone NOT NULL DEFAULT now(),
    CONSTRAINT user_pkey PRIMARY KEY (user_id),
    CONSTRAINT user_email_key UNIQUE (email),
    CONSTRAINT user_username_key UNIQUE (username)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public."user"
    OWNER to postgres;

-- Table: public.ux_instrument

-- DROP TABLE IF EXISTS public.ux_instrument;

CREATE TABLE IF NOT EXISTS public.ux_instrument
(
    instrument_id integer NOT NULL DEFAULT nextval('ux_instrument_instrument_id_seq'::regclass),
    name character varying(32) COLLATE pg_catalog."default" NOT NULL,
    description text COLLATE pg_catalog."default",
    version character varying(16) COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT ux_instrument_pkey PRIMARY KEY (instrument_id),
    CONSTRAINT ux_instrument_name_key UNIQUE (name),
    CONSTRAINT chk_instrument_name CHECK (name::text = ANY (ARRAY['PENS'::character varying, 'GUESS'::character varying, 'BANGS'::character varying]::text[]))
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.ux_instrument
    OWNER to postgres;

-- Table: public.ux_item

-- DROP TABLE IF EXISTS public.ux_item;

CREATE TABLE IF NOT EXISTS public.ux_item
(
    item_id integer NOT NULL DEFAULT nextval('ux_item_item_id_seq'::regclass),
    instrument_id integer NOT NULL,
    question_text text COLLATE pg_catalog."default" NOT NULL,
    response_type character varying(32) COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT ux_item_pkey PRIMARY KEY (item_id),
    CONSTRAINT fk_item_instrument FOREIGN KEY (instrument_id)
        REFERENCES public.ux_instrument (instrument_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE CASCADE,
    CONSTRAINT chk_response_type CHECK (response_type::text = ANY (ARRAY['likert'::character varying, 'open'::character varying, 'binary'::character varying]::text[]))
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.ux_item
    OWNER to postgres;

-- Table: public.ux_response

-- DROP TABLE IF EXISTS public.ux_response;

CREATE TABLE IF NOT EXISTS public.ux_response
(
    response_id integer NOT NULL DEFAULT nextval('ux_response_response_id_seq'::regclass),
    user_id integer NOT NULL,
    instrument_id integer NOT NULL,
    game_id integer NOT NULL,
    submitted_at timestamp without time zone NOT NULL DEFAULT now(),
    CONSTRAINT ux_response_pkey PRIMARY KEY (response_id),
    CONSTRAINT fk_response_game FOREIGN KEY (game_id)
        REFERENCES public.game (game_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE CASCADE,
    CONSTRAINT fk_response_instrument FOREIGN KEY (instrument_id)
        REFERENCES public.ux_instrument (instrument_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT fk_response_user FOREIGN KEY (user_id)
        REFERENCES public."user" (user_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE CASCADE
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.ux_response
    OWNER to postgres;

-- Table: public.ux_response_item

-- DROP TABLE IF EXISTS public.ux_response_item;

CREATE TABLE IF NOT EXISTS public.ux_response_item
(
    response_item_id integer NOT NULL DEFAULT nextval('ux_response_item_response_item_id_seq'::regclass),
    response_id integer NOT NULL,
    item_id integer NOT NULL,
    response_value character varying(256) COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT ux_response_item_pkey PRIMARY KEY (response_item_id),
    CONSTRAINT fk_response_item_item FOREIGN KEY (item_id)
        REFERENCES public.ux_item (item_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT fk_response_item_response FOREIGN KEY (response_id)
        REFERENCES public.ux_response (response_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE CASCADE
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.ux_response_item
    OWNER to postgres;