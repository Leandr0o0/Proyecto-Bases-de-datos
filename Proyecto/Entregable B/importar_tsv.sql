-- ============================================================
--  Carga el TSV (andres.tsv) en staging y ejecuta ETL
--
--  INSTRUCCIONES:
--  1. Corre el BLOQUE 1 (crea tabla temporal)
--  2. Importa andres.tsv a tmp_import desde pgAdmin:
--       clic derecho en tmp_import → Import/Export Data
--       Formato: csv, Delimitador: Tab, Header: OFF
--       NO tocar la pestaña Columns (dejar vacío = todas)
--  3. Corre el BLOQUE 2 (pasa datos y ejecuta ETL)
-- ============================================================

-- ══════════════════════════════════════════════════════════════
--  BLOQUE 1 — Correr ANTES de importar el TSV
-- ══════════════════════════════════════════════════════════════

-- Limpiar staging de ejecuciones previas
TRUNCATE staging_telemetry RESTART IDENTITY;
TRUNCATE etl_error_log     RESTART IDENTITY;

-- Tabla temporal que coincide exactamente con las 9 columnas del TSV
-- (sin raw_id ni otros campos automáticos)
DROP TABLE IF EXISTS tmp_import;

CREATE TABLE tmp_import (
    ts         TEXT,
    tic        TEXT,
    x          TEXT,
    y          TEXT,
    z          TEXT,
    angle      TEXT,
    momx       TEXT,
    momy       TEXT,
    sector_raw TEXT
);

-- ══════════════════════════════════════════════════════════════
--  BLOQUE 2 — Correr DESPUÉS de importar el TSV a tmp_import
-- ══════════════════════════════════════════════════════════════

-- Pasar datos de tmp_import a staging_telemetry
INSERT INTO staging_telemetry (ts, tic, x, y, z, angle, momx, momy, sector_raw)
SELECT ts, tic, x, y, z, angle, momx, momy, sector_raw
FROM tmp_import;

-- Verificar filas cargadas (debe dar 275)
SELECT COUNT(*) AS filas_en_staging FROM staging_telemetry;
SELECT COUNT(*) FROM tmp_import;
-- Asignar game_id y player_id a esta sesión
-- (game_id=1, player_id=1 corresponden a la partida de andres.tsv)
UPDATE staging_telemetry
SET game_id   = 1,
    player_id = 1
WHERE status = 'pending';

-- Ejecutar ETL: validación + inserción en telemetry_event
SELECT * FROM etl_load_telemetry();

-- Verificar resultados
SELECT * FROM v_etl_summary;

SELECT COUNT(*) AS filas_en_telemetry_event FROM telemetry_event;

SELECT COUNT(*) AS errores, reason
FROM etl_error_log
GROUP BY reason;

-- Limpiar tabla temporal
DROP TABLE IF EXISTS tmp_import;