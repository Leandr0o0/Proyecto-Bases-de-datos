-- 1. Limpiamos staging con CASCADE
TRUNCATE staging_telemetry CASCADE;

-- 2. Importamos tu archivo plano
COPY staging_telemetry (
    map_id_raw, ts_raw, tic_raw, x_raw, y_raw, z_raw,
    angle_raw, momx_raw, momy_raw, health_raw, armor_raw,
    ammo_raw, sector_grid_raw
)
FROM 'C:\Users\estudiante\Documents\bases de datos\Entrega 2\telemetry\alejandro.tsv'
WITH (FORMAT text, DELIMITER E'\t', HEADER false);

-- 3. Te asignamos tus game_id automáticos
SELECT assign_game_id(1);

-- 4. Insertamos sectores únicos en la tabla sector
INSERT INTO sector (sector_id, map_id, sector_name)
SELECT DISTINCT
  ( CAST(regexp_replace(sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\1') AS INT) + 200 ) * 1000
  + ( CAST(regexp_replace(sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\2') AS INT) + 200 )
    AS sector_id,
  map_id_raw::INT AS map_id,
  'Grid ' || sector_grid_raw AS sector_name
FROM staging_telemetry
WHERE is_valid = TRUE AND sector_grid_raw IS NOT NULL
ON CONFLICT DO NOTHING;

-- 5. Insertamos en telemetry_event quitando health y armor para evitar el error
INSERT INTO telemetry_event (game_id, sector_id, map_id, tic, ts, x, y, z, angle, momx, momy, ammo)
SELECT
  s.game_id,
  ( CAST(regexp_replace(s.sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\1') AS INT) + 200 ) * 1000
  + ( CAST(regexp_replace(s.sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\2') AS INT) + 200 )
    AS sector_id,
  s.map_id_raw::INT,
  s.tic_raw::INT,
  s.ts_raw::TIMESTAMP,
  s.x_raw::FLOAT,
  s.y_raw::FLOAT,
  NULLIF(s.z_raw,    '')::FLOAT,
  NULLIF(s.angle_raw,'')::FLOAT,
  NULLIF(s.momx_raw, '')::FLOAT,
  NULLIF(s.momy_raw, '')::FLOAT,
  s.ammo_raw::INT
FROM staging_telemetry s
WHERE s.is_valid = TRUE
  AND NOT EXISTS (
    SELECT 1 FROM telemetry_event te
    WHERE te.game_id = s.game_id
      AND te.tic     = s.tic_raw::INT
  );

--------------------------------------------------------------------------------
--Nicolas
TRUNCATE staging_telemetry CASCADE;

COPY staging_telemetry (map_id_raw, ts_raw, tic_raw, x_raw, y_raw, z_raw, angle_raw, momx_raw, momy_raw, health_raw, armor_raw, ammo_raw, sector_grid_raw)
FROM 'C:\Users\estudiante\Documents\bases de datos\Entrega 2\telemetry\nicolas.tsv' WITH (FORMAT text, DELIMITER E'\t', HEADER false);

SELECT assign_game_id(2); -- <-- ID 2 para Nicolas

UPDATE staging_telemetry SET is_valid = TRUE WHERE is_valid IS NULL;
UPDATE staging_telemetry SET is_valid = FALSE, error_msg = 'sector_grid_raw formato inválido' WHERE is_valid = TRUE AND sector_grid_raw !~ '^\(-?[0-9]+,-?[0-9]+\)$';
UPDATE staging_telemetry SET is_valid = FALSE, error_msg = 'game_id no asignado' WHERE is_valid = TRUE AND game_id IS NULL;

INSERT INTO sector (sector_id, map_id, sector_name)
SELECT DISTINCT (CAST(regexp_replace(sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\1') AS INT)+200)*1000 + (CAST(regexp_replace(sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\2') AS INT)+200), map_id_raw::INT, 'Grid ' || sector_grid_raw FROM staging_telemetry WHERE is_valid = TRUE AND sector_grid_raw IS NOT NULL ON CONFLICT DO NOTHING;

INSERT INTO telemetry_event (game_id, sector_id, map_id, tic, ts, x, y, z, angle, momx, momy, ammo)
SELECT s.game_id, (CAST(regexp_replace(s.sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\1') AS INT)+200)*1000 + (CAST(regexp_replace(s.sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\2') AS INT)+200), s.map_id_raw::INT, s.tic_raw::INT, s.ts_raw::TIMESTAMP, s.x_raw::FLOAT, s.y_raw::FLOAT, NULLIF(s.z_raw, '')::FLOAT, NULLIF(s.angle_raw,'')::FLOAT, NULLIF(s.momx_raw, '')::FLOAT, NULLIF(s.momy_raw, '')::FLOAT, s.ammo_raw::INT FROM staging_telemetry s WHERE s.is_valid = TRUE AND NOT EXISTS (SELECT 1 FROM telemetry_event te WHERE te.game_id = s.game_id AND te.tic = s.tic_raw::INT);

------------------------------------------------
--juan jose
TRUNCATE staging_telemetry CASCADE;

COPY staging_telemetry (map_id_raw, ts_raw, tic_raw, x_raw, y_raw, z_raw, angle_raw, momx_raw, momy_raw, health_raw, armor_raw, ammo_raw, sector_grid_raw)
FROM 'C:\Users\estudiante\Documents\bases de datos\Entrega 2\telemetry\juanjose.tsv' WITH (FORMAT text, DELIMITER E'\t', HEADER false);

SELECT assign_game_id(3); -- <-- ID 3 para Juan José

UPDATE staging_telemetry SET is_valid = TRUE WHERE is_valid IS NULL;
UPDATE staging_telemetry SET is_valid = FALSE, error_msg = 'sector_grid_raw formato inválido' WHERE is_valid = TRUE AND sector_grid_raw !~ '^\(-?[0-9]+,-?[0-9]+\)$';
UPDATE staging_telemetry SET is_valid = FALSE, error_msg = 'game_id no asignado' WHERE is_valid = TRUE AND game_id IS NULL;

INSERT INTO sector (sector_id, map_id, sector_name)
SELECT DISTINCT (CAST(regexp_replace(sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\1') AS INT)+200)*1000 + (CAST(regexp_replace(sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\2') AS INT)+200), map_id_raw::INT, 'Grid ' || sector_grid_raw FROM staging_telemetry WHERE is_valid = TRUE AND sector_grid_raw IS NOT NULL ON CONFLICT DO NOTHING;

INSERT INTO telemetry_event (game_id, sector_id, map_id, tic, ts, x, y, z, angle, momx, momy, ammo)
SELECT s.game_id, (CAST(regexp_replace(s.sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\1') AS INT)+200)*1000 + (CAST(regexp_replace(s.sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\2') AS INT)+200), s.map_id_raw::INT, s.tic_raw::INT, s.ts_raw::TIMESTAMP, s.x_raw::FLOAT, s.y_raw::FLOAT, NULLIF(s.z_raw, '')::FLOAT, NULLIF(s.angle_raw,'')::FLOAT, NULLIF(s.momx_raw, '')::FLOAT, NULLIF(s.momy_raw, '')::FLOAT, s.ammo_raw::INT FROM staging_telemetry s WHERE s.is_valid = TRUE AND NOT EXISTS (SELECT 1 FROM telemetry_event te WHERE te.game_id = s.game_id AND te.tic = s.tic_raw::INT);

----------------------------------------------------------
--laura
TRUNCATE staging_telemetry CASCADE;

COPY staging_telemetry (map_id_raw, ts_raw, tic_raw, x_raw, y_raw, z_raw, angle_raw, momx_raw, momy_raw, health_raw, armor_raw, ammo_raw, sector_grid_raw)
FROM 'C:\Users\estudiante\Documents\bases de datos\Entrega 2\telemetry\laura.tsv' WITH (FORMAT text, DELIMITER E'\t', HEADER false);

SELECT assign_game_id(4); -- <-- ID 4 para Laura

UPDATE staging_telemetry SET is_valid = TRUE WHERE is_valid IS NULL;
UPDATE staging_telemetry SET is_valid = FALSE, error_msg = 'sector_grid_raw formato inválido' WHERE is_valid = TRUE AND sector_grid_raw !~ '^\(-?[0-9]+,-?[0-9]+\)$';
UPDATE staging_telemetry SET is_valid = FALSE, error_msg = 'game_id no asignado' WHERE is_valid = TRUE AND game_id IS NULL;

INSERT INTO sector (sector_id, map_id, sector_name)
SELECT DISTINCT (CAST(regexp_replace(sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\1') AS INT)+200)*1000 + (CAST(regexp_replace(sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\2') AS INT)+200), map_id_raw::INT, 'Grid ' || sector_grid_raw FROM staging_telemetry WHERE is_valid = TRUE AND sector_grid_raw IS NOT NULL ON CONFLICT DO NOTHING;

INSERT INTO telemetry_event (game_id, sector_id, map_id, tic, ts, x, y, z, angle, momx, momy, ammo)
SELECT s.game_id, (CAST(regexp_replace(s.sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\1') AS INT)+200)*1000 + (CAST(regexp_replace(s.sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\2') AS INT)+200), s.map_id_raw::INT, s.tic_raw::INT, s.ts_raw::TIMESTAMP, s.x_raw::FLOAT, s.y_raw::FLOAT, NULLIF(s.z_raw, '')::FLOAT, NULLIF(s.angle_raw,'')::FLOAT, NULLIF(s.momx_raw, '')::FLOAT, NULLIF(s.momy_raw, '')::FLOAT, s.ammo_raw::INT FROM staging_telemetry s WHERE s.is_valid = TRUE AND NOT EXISTS (SELECT 1 FROM telemetry_event te WHERE te.game_id = s.game_id AND te.tic = s.tic_raw::INT);

------------------------------------------------
--sebastian
TRUNCATE staging_telemetry CASCADE;

COPY staging_telemetry (map_id_raw, ts_raw, tic_raw, x_raw, y_raw, z_raw, angle_raw, momx_raw, momy_raw, health_raw, armor_raw, ammo_raw, sector_grid_raw)
FROM 'C:\Users\estudiante\Documents\bases de datos\Entrega 2\telemetry\sebastian.tsv' WITH (FORMAT text, DELIMITER E'\t', HEADER false);

SELECT assign_game_id(5); -- <-- ID 5 para Sebastian

UPDATE staging_telemetry SET is_valid = TRUE WHERE is_valid IS NULL;
UPDATE staging_telemetry SET is_valid = FALSE, error_msg = 'sector_grid_raw formato inválido' WHERE is_valid = TRUE AND sector_grid_raw !~ '^\(-?[0-9]+,-?[0-9]+\)$';
UPDATE staging_telemetry SET is_valid = FALSE, error_msg = 'game_id no asignado' WHERE is_valid = TRUE AND game_id IS NULL;

INSERT INTO sector (sector_id, map_id, sector_name)
SELECT DISTINCT (CAST(regexp_replace(sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\1') AS INT)+200)*1000 + (CAST(regexp_replace(sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\2') AS INT)+200), map_id_raw::INT, 'Grid ' || sector_grid_raw FROM staging_telemetry WHERE is_valid = TRUE AND sector_grid_raw IS NOT NULL ON CONFLICT DO NOTHING;

INSERT INTO telemetry_event (game_id, sector_id, map_id, tic, ts, x, y, z, angle, momx, momy, ammo)
SELECT s.game_id, (CAST(regexp_replace(s.sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\1') AS INT)+200)*1000 + (CAST(regexp_replace(s.sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\2') AS INT)+200), s.map_id_raw::INT, s.tic_raw::INT, s.ts_raw::TIMESTAMP, s.x_raw::FLOAT, s.y_raw::FLOAT, NULLIF(s.z_raw, '')::FLOAT, NULLIF(s.angle_raw,'')::FLOAT, NULLIF(s.momx_raw, '')::FLOAT, NULLIF(s.momy_raw, '')::FLOAT, s.ammo_raw::INT FROM staging_telemetry s WHERE s.is_valid = TRUE AND NOT EXISTS (SELECT 1 FROM telemetry_event te WHERE te.game_id = s.game_id AND te.tic = s.tic_raw::INT);

-----------------------------------------------------------------------------
--Cristian
TRUNCATE staging_telemetry CASCADE;

COPY staging_telemetry (map_id_raw, ts_raw, tic_raw, x_raw, y_raw, z_raw, angle_raw, momx_raw, momy_raw, health_raw, armor_raw, ammo_raw, sector_grid_raw)
FROM 'C:\Users\estudiante\Documents\bases de datos\Entrega 2\telemetry\cristian.tsv' WITH (FORMAT text, DELIMITER E'\t', HEADER false);

SELECT assign_game_id(6); -- <-- ID 6 para Cristian

UPDATE staging_telemetry SET is_valid = TRUE WHERE is_valid IS NULL;
UPDATE staging_telemetry SET is_valid = FALSE, error_msg = 'sector_grid_raw formato inválido' WHERE is_valid = TRUE AND sector_grid_raw !~ '^\(-?[0-9]+,-?[0-9]+\)$';
UPDATE staging_telemetry SET is_valid = FALSE, error_msg = 'game_id no asignado' WHERE is_valid = TRUE AND game_id IS NULL;

INSERT INTO sector (sector_id, map_id, sector_name)
SELECT DISTINCT (CAST(regexp_replace(sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\1') AS INT)+200)*1000 + (CAST(regexp_replace(sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\2') AS INT)+200), map_id_raw::INT, 'Grid ' || sector_grid_raw FROM staging_telemetry WHERE is_valid = TRUE AND sector_grid_raw IS NOT NULL ON CONFLICT DO NOTHING;

INSERT INTO telemetry_event (game_id, sector_id, map_id, tic, ts, x, y, z, angle, momx, momy, ammo)
SELECT s.game_id, (CAST(regexp_replace(s.sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\1') AS INT)+200)*1000 + (CAST(regexp_replace(s.sector_grid_raw, '^\((-?[0-9]+),(-?[0-9]+)\)$', '\2') AS INT)+200), s.map_id_raw::INT, s.tic_raw::INT, s.ts_raw::TIMESTAMP, s.x_raw::FLOAT, s.y_raw::FLOAT, NULLIF(s.z_raw, '')::FLOAT, NULLIF(s.angle_raw,'')::FLOAT, NULLIF(s.momx_raw, '')::FLOAT, NULLIF(s.momy_raw, '')::FLOAT, s.ammo_raw::INT FROM staging_telemetry s WHERE s.is_valid = TRUE AND NOT EXISTS (SELECT 1 FROM telemetry_event te WHERE te.game_id = s.game_id AND te.tic = s.tic_raw::INT);