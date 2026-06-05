-- ============================================================
-- 03_queries_indexes_views.sql
-- Parte C – Queries analíticas, índices y vistas
-- Chocolate-Doom Telemetry & UX Database
-- ============================================================

-- ============================================================
-- SECCIÓN 1 – ÍNDICES
-- (Los 3 del DDL ya existen; aquí se documentan y evalúan)
-- ============================================================

-- Los índices fueron creados en ddl_schema.sql:
--   idx_te_game_tic    ON telemetry_event (game_id, tic)
--   idx_te_map_sector  ON telemetry_event (map_id, sector_id)
--   idx_te_pos         ON telemetry_event USING gist(point(x,y))
--   idx_game_player    ON game (player_id, game_id)

-- Para evaluar impacto, correr EXPLAIN ANALYZE antes y después
-- de cada índice. Ejemplo con idx_te_game_tic:

-- >> ANTES (eliminar índice temporalmente):
-- DROP INDEX IF EXISTS idx_te_game_tic;
-- EXPLAIN ANALYZE
-- SELECT tic, x, y FROM telemetry_event WHERE game_id = 1 ORDER BY tic;

-- >> DESPUÉS (recrear):
-- CREATE INDEX idx_te_game_tic ON telemetry_event (game_id, tic);
-- EXPLAIN ANALYZE
-- SELECT tic, x, y FROM telemetry_event WHERE game_id = 1 ORDER BY tic;

-- Copiar los resultados (Seq Scan vs Index Scan, tiempos)
-- al reporte PDF en la sección de indexing.

-- ============================================================
-- SECCIÓN 2 – QUERIES ANALÍTICAS
-- ============================================================

-- ------------------------------------------------------------
-- Q1: Duración promedio de sesiones de juego por mapa
-- ------------------------------------------------------------
-- Calcula cuántos segundos duró en promedio cada partida,
-- agrupado por mapa. Usa los timestamps de inicio y fin de game.

SELECT
    m.map_code,
    m.map_name,
    COUNT(g.game_id)                                         AS total_sesiones,
    ROUND(AVG(EXTRACT(EPOCH FROM (g.end_time - g.start_time))), 2)
                                                             AS duracion_promedio_seg,
    ROUND(AVG(EXTRACT(EPOCH FROM (g.end_time - g.start_time))) / 60, 2)
                                                             AS duracion_promedio_min
FROM game g
JOIN map m ON m.map_id = g.map_id
WHERE g.end_time IS NOT NULL
GROUP BY m.map_id, m.map_code, m.map_name
ORDER BY duracion_promedio_seg DESC;

-- ------------------------------------------------------------
-- Q3: Trayectoria más corta y más larga por jugador (CORREGIDA)
-- ------------------------------------------------------------
WITH pasos_consecutivos AS (
    -- Paso 1: Calculamos el LAG y la distancia individual de cada movimiento por tic
    SELECT
        te.game_id,
        g.player_id,
        SQRT(
            POWER(te.x - LAG(te.x) OVER (PARTITION BY te.game_id ORDER BY te.tic), 2) +
            POWER(te.y - LAG(te.y) OVER (PARTITION BY te.game_id ORDER BY te.tic), 2)
        ) AS distancia_paso
    FROM telemetry_event te
    JOIN game g ON g.game_id = te.game_id
),
trayectoria_por_game AS (
    -- Paso 2: Ahora sí podemos agrupar por game y SUMAR las distancias individuales
    SELECT
        game_id,
        player_id,
        SUM(distancia_paso) AS distancia_total
    FROM pasos_consecutivos
    WHERE distancia_paso IS NOT NULL
    GROUP BY game_id, player_id
)
SELECT
    p.nickname                               AS jugador,
    ROUND(MIN(distancia_total)::NUMERIC, 2)  AS trayectoria_mas_corta,
    ROUND(MAX(distancia_total)::NUMERIC, 2)  AS trayectoria_mas_larga,
    ROUND(AVG(distancia_total)::NUMERIC, 2)  AS trayectoria_promedio
FROM trayectoria_por_game tpg
JOIN player p ON p.player_id = tpg.player_id
GROUP BY p.player_id, p.nickname
ORDER BY trayectoria_mas_larga DESC;

-- ------------------------------------------------------------
-- Q4: Respuestas UX de jugadores con trayectoria sobre el promedio
-- ------------------------------------------------------------
-- Primero calcula la duración promedio global (en tics),
-- luego filtra jugadores que superan ese promedio y
-- muestra sus respuestas al instrumento BANGS.

-- ------------------------------------------------------------
-- Q: Average UX Score for Players with the Shortest Trajectory per Episode
-- ------------------------------------------------------------

WITH pasos AS (
    -- Paso 1: Calculamos la distancia individual entre tics
    SELECT
        g.player_id,
        te.game_id,
        m.episode_id,
        SQRT(
            POWER(te.x - LAG(te.x) OVER (PARTITION BY te.game_id ORDER BY te.tic), 2) +
            POWER(te.y - LAG(te.y) OVER (PARTITION BY te.game_id ORDER BY te.tic), 2)
        ) AS distancia_paso
    FROM telemetry_event te
    JOIN game g ON g.game_id = te.game_id
    JOIN map  m ON m.map_id  = g.map_id
),
distancia_por_episodio AS (
    -- Paso 2: Sumamos la distancia total recorrida por cada jugador en cada episodio
    SELECT
        player_id,
        episode_id,
        SUM(distancia_paso) AS distancia_total
    FROM pasos
    WHERE distancia_paso IS NOT NULL
    GROUP BY player_id, episode_id
),
ranking_jugadores AS (
    -- Paso 3: Usamos una función de ventana para clasificar (rankear) a los jugadores 
    -- por su distancia de menor a mayor (ASC) dentro de cada episodio
    SELECT
        player_id,
        episode_id,
        distancia_total,
        RANK() OVER (PARTITION BY episode_id ORDER BY distancia_total ASC) as ranking_minimo
    FROM distancia_por_episodio
),
jugadores_trayectoria_mas_corta AS (
    -- Paso 4: Filtramos para quedarnos ÚNICAMENTE con los que quedaron en 1er lugar (ruta más corta)
    SELECT player_id, episode_id, distancia_total
    FROM ranking_jugadores
    WHERE ranking_minimo = 1
)
-- Paso 5: Unimos a estos jugadores estrella con sus respuestas de UX y promediamos
SELECT 
    e.name                                     AS episodio,
    p.nickname                                 AS jugador_ruta_corta,
    ROUND(jtmc.distancia_total::NUMERIC, 2)    AS distancia_recorrida,
    ROUND(AVG(uri.response_value::NUMERIC), 2) AS puntaje_ux_promedio
FROM jugadores_trayectoria_mas_corta jtmc
JOIN episode e            ON e.episode_id  = jtmc.episode_id
JOIN player p             ON p.player_id   = jtmc.player_id
JOIN "user" u             ON u.user_id     = p.user_id
JOIN ux_response ur       ON ur.user_id    = u.user_id
JOIN ux_response_item uri ON uri.response_id = ur.response_id
GROUP BY e.name, p.nickname, jtmc.distancia_total
ORDER BY e.name;

-- ------------------------------------------------------------
-- Q5: Sector más visitado (hotspot) por episodio y mapa
-- ------------------------------------------------------------
-- Cuenta cuántos tics registró cada sector en cada mapa,
-- y devuelve el TOP 3 sectores más visitados por mapa.

WITH visitas_sector AS (
    SELECT
        e.name        AS episodio,
        m.map_code,
        s.sector_name AS sector,
        COUNT(*)      AS total_tics,
        RANK() OVER (
            PARTITION BY te.map_id
            ORDER BY COUNT(*) DESC
        ) AS ranking
    FROM telemetry_event te
    JOIN map    m ON m.map_id    = te.map_id
    JOIN episode e ON e.episode_id = m.episode_id
    JOIN sector s ON s.sector_id = te.sector_id
                 AND s.map_id    = te.map_id
    GROUP BY e.name, m.map_code, te.map_id, s.sector_name, te.sector_id
)
SELECT episodio, map_code, sector, total_tics, ranking
FROM visitas_sector
WHERE ranking <= 3
ORDER BY map_code, ranking;

-- ------------------------------------------------------------
-- Q6: Tics de co-presencia en el mismo sector entre jugadores
-- ------------------------------------------------------------
-- Cuenta cuántos tics distintos dos jugadores compartieron
-- el mismo sector dentro de la misma partida (mismo map_id y tic).
-- Self-join sobre telemetry_event.

SELECT
    p1.nickname                     AS jugador_1,
    p2.nickname                     AS jugador_2,
    m.map_code,
    COUNT(DISTINCT te1.tic)         AS tics_juntos
FROM telemetry_event te1
JOIN telemetry_event te2
    ON  te1.map_id    = te2.map_id
    AND te1.tic       = te2.tic
    AND te1.sector_id = te2.sector_id
    AND te1.game_id  <> te2.game_id   -- partidas distintas, mismo mapa y tic
JOIN game   g1 ON g1.game_id   = te1.game_id
JOIN game   g2 ON g2.game_id   = te2.game_id
JOIN player p1 ON p1.player_id = g1.player_id
JOIN player p2 ON p2.player_id = g2.player_id
JOIN map    m  ON m.map_id     = te1.map_id
WHERE g1.player_id < g2.player_id   -- evitar duplicados (A,B) y (B,A)
GROUP BY p1.nickname, p2.nickname, m.map_code
ORDER BY tics_juntos DESC
LIMIT 20;

-- ------------------------------------------------------------
-- Q8: Distancia total y velocidad promedio por jugador (todos los games)
-- ------------------------------------------------------------
-- Suma distancias euclidianas consecutivas en todos los games
-- de un jugador, y divide por el total de tics para obtener
-- la velocidad promedio (unidades Doom / tic).

WITH pasos AS (
    SELECT
        g.player_id,
        te.game_id,
        te.tic,
        SQRT(
            POWER(te.x - LAG(te.x) OVER (PARTITION BY te.game_id ORDER BY te.tic), 2) +
            POWER(te.y - LAG(te.y) OVER (PARTITION BY te.game_id ORDER BY te.tic), 2)
        ) AS distancia_paso
    FROM telemetry_event te
    JOIN game g ON g.game_id = te.game_id
),
totales_por_jugador AS (
    SELECT
        player_id,
        SUM(distancia_paso)                AS distancia_total,
        COUNT(*)                           AS total_tics,
        COUNT(DISTINCT game_id)            AS total_games
    FROM pasos
    WHERE distancia_paso IS NOT NULL
    GROUP BY player_id
)
SELECT
    p.nickname                                          AS jugador,
    t.total_games,
    t.total_tics,
    ROUND(t.distancia_total::NUMERIC,      2)           AS distancia_total_doom_units,
    ROUND((t.distancia_total / NULLIF(t.total_tics, 0))::NUMERIC, 4)
                                                        AS velocidad_promedio_u_por_tic
FROM totales_por_jugador t
JOIN player p ON p.player_id = t.player_id
ORDER BY distancia_total_doom_units DESC;

-- ============================================================
-- SECCIÓN 3 – VISTAS
-- ============================================================
-- ------------------------------------------------------------
-- Vista 1: resumen_trayectoria_jugador 
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW resumen_trayectoria_jugador AS
WITH pasos AS (
    -- Primer nivel: Calcula distancias entre tics individuales
    SELECT
        g.player_id,
        te.game_id,
        te.map_id,
        te.tic,
        SQRT(
            POWER(te.x - LAG(te.x) OVER (PARTITION BY te.game_id ORDER BY te.tic), 2) +
            POWER(te.y - LAG(te.y) OVER (PARTITION BY te.game_id ORDER BY te.tic), 2)
        ) AS distancia_paso
    FROM telemetry_event te
    JOIN game g ON g.game_id = te.game_id
),
totales_por_partida AS (
    -- Segundo nivel: Agrupa y calcula agregaciones por partida
    SELECT
        player_id,
        game_id,
        map_id,
        COUNT(tic) AS total_tics,
        SUM(distancia_paso) AS distancia_total,
        AVG(distancia_paso) AS velocidad_promedio
    FROM pasos
    WHERE distancia_paso IS NOT NULL
    GROUP BY player_id, game_id, map_id
)
-- Nivel final: Une con los catálogos para mostrar nombres legibles
SELECT
    p.nickname                                AS jugador,
    tpp.game_id,
    m.map_code,
    tpp.total_tics,
    ROUND(tpp.distancia_total::NUMERIC, 2)     AS distancia_total,
    ROUND(tpp.velocidad_promedio::NUMERIC, 4)  AS velocidad_promedio
FROM totales_por_partida tpp
JOIN player p ON p.player_id = tpp.player_id
JOIN map    m ON m.map_id    = tpp.map_id;

-- ------------------------------------------------------------
-- Vista 2: resumen_ux_jugador
-- Puntuación media por subescala BANGS para cada jugador.
-- Útil para cruzar experiencia UX con métricas de telemetría.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW resumen_ux_jugador AS
SELECT
    p.nickname                                      AS jugador,
    ui.name                                         AS instrumento,
    -- Subescala detectada por el prefijo entre corchetes en question_text
    CASE
        WHEN uxi.question_text LIKE '[C%' THEN 'Competencia'
        WHEN uxi.question_text LIKE '[A%' THEN 'Autonomia'
        WHEN uxi.question_text LIKE '[R%' THEN 'Relacion'
        ELSE 'Otro'
    END                                             AS subescala,
    ROUND(AVG(uri.response_value::NUMERIC), 2)      AS puntaje_promedio,
    COUNT(uri.response_item_id)                     AS items_respondidos
FROM ux_response      ur
JOIN ux_response_item uri ON uri.response_id   = ur.response_id
JOIN ux_item          uxi ON uxi.item_id       = uri.item_id
JOIN ux_instrument    ui  ON ui.instrument_id  = ur.instrument_id
JOIN "user"           u   ON u.user_id         = ur.user_id
JOIN player           p   ON p.user_id         = u.user_id
GROUP BY p.nickname, ui.name, subescala
ORDER BY p.nickname, subescala;

-- ------------------------------------------------------------
-- Vista Materializada: hotspot_sectores
-- Pre-agrega visitas por sector/mapa para consultas rápidas
-- de análisis espacial. Refrescar con REFRESH MATERIALIZED VIEW.
-- ------------------------------------------------------------
CREATE MATERIALIZED VIEW IF NOT EXISTS hotspot_sectores AS
SELECT
    e.name        AS episodio,
    m.map_code,
    m.map_id,
    s.sector_id,
    s.sector_name,
    COUNT(*)      AS total_visitas,
    COUNT(DISTINCT g.player_id) AS jugadores_distintos
FROM telemetry_event te
JOIN game    g ON g.game_id    = te.game_id
JOIN map     m ON m.map_id     = te.map_id
JOIN episode e ON e.episode_id = m.episode_id
JOIN sector  s ON s.sector_id  = te.sector_id
             AND s.map_id      = te.map_id
GROUP BY e.name, m.map_code, m.map_id, s.sector_id, s.sector_name
WITH DATA;

-- Índice sobre la vista materializada para acelerar ORDER BY visitas
CREATE INDEX IF NOT EXISTS idx_hotspot_visitas
    ON hotspot_sectores (map_id, total_visitas DESC);

-- Para refrescar (correr cuando se carguen nuevos datos):
-- REFRESH MATERIALIZED VIEW hotspot_sectores;

-- Consulta de ejemplo sobre la vista materializada:
SELECT *
FROM hotspot_sectores
ORDER BY map_id, total_visitas DESC
LIMIT 10;

-- ============================================================
-- SECCIÓN 4 – EXPLAIN ANALYZE (plantillas para el reporte)
-- ============================================================
-- Copiar cada bloque, ejecutarlo en pgAdmin, y capturar
-- el plan de ejecución con los tiempos para el PDF.

-- >> Test 1: idx_te_game_tic (Q3, Q8 se benefician de este)
--Sin Indice
DROP INDEX IF EXISTS idx_te_game_tic;

EXPLAIN ANALYZE
SELECT tic, x, y
FROM telemetry_event
WHERE game_id = 1
ORDER BY tic;

--con indice
CREATE INDEX idx_te_game_tic
ON telemetry_event (game_id, tic);

EXPLAIN ANALYZE
SELECT tic, x, y
FROM telemetry_event
WHERE game_id = 1
ORDER BY tic;

-- >> Test 2: idx_te_map_sector (Q5, Q6)

--sin indice

DROP INDEX IF EXISTS idx_te_map_sector;

EXPLAIN ANALYZE
SELECT COUNT(*)
FROM telemetry_event
WHERE map_id = 1
AND sector_id = 1;

--con indice

CREATE INDEX idx_te_map_sector
ON telemetry_event (map_id, sector_id);

EXPLAIN ANALYZE
SELECT COUNT(*)
FROM telemetry_event
WHERE map_id = 1
AND sector_id = 1;

-- >> Test 3: idx_te_pos — consulta de proximidad espacial

--sin indice

DROP INDEX IF EXISTS idx_te_pos;

EXPLAIN ANALYZE
SELECT *
FROM telemetry_event
WHERE point(x,y) <@ circle(point(100,100),50);

--Con indice

CREATE INDEX idx_te_pos
ON telemetry_event
USING gist (point(x,y));

EXPLAIN ANALYZE
SELECT *
FROM telemetry_event
WHERE point(x,y) <@ circle(point(100,100),50);