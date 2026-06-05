-- ============================================================
-- 01_seed_master.sql
-- Pobla: episode, map, sector, "user", player, game
--        ux_instrument, ux_item (BANGS completo)
-- Ejecutar ANTES del ETL de telemetría.
-- ============================================================

-- ------------------------------------------------------------
-- EPISODIOS  (los TSV tienen map_id 1,2,3)
-- ------------------------------------------------------------
INSERT INTO episode (episode_id, name, description) VALUES
  (1, 'Knee-Deep in the Dead', 'Episode 1 – UAC Mars facility'),
  (2, 'The Shores of Hell',    'Episode 2 – Deimos installation'),
  (3, 'Inferno',               'Episode 3 – Hell itself')
ON CONFLICT DO NOTHING;

-- Reiniciar secuencia si ya había datos
SELECT setval('episode_episode_id_seq', 3);

-- ------------------------------------------------------------
-- MAPAS (uno por episodio, map_code alineado con el motor)
-- ------------------------------------------------------------
INSERT INTO map (map_id, episode_id, map_code, map_name) VALUES
  (1, 1, 'E1M1', 'Hangar'),
  (2, 2, 'E2M1', 'Deimos Anomaly'),
  (3, 3, 'E3M1', 'Hell Keep')
ON CONFLICT DO NOTHING;

SELECT setval('map_map_id_seq', 3);

-- ------------------------------------------------------------
-- SECTORES  (celdas de grilla 250×250 por mapa)
-- Los pares (gx,gy) del TSV se normalizan a un entero:
--   sector_id = (gx + 100) * 1000 + (gy + 100)
-- Este bloque se llena dinámicamente desde staging (ver ETL).
-- Aquí solo se registra la convención para el diccionario.
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- USUARIOS  (uno por archivo TSV)
-- Datos de ejemplo; ajustar con los datos reales del grupo.
-- ------------------------------------------------------------
INSERT INTO "user"
  (user_id, username, email, consent_given, consent_date,
   age, gender, experience)
VALUES
  (1, 'alejandro', 'alejandro@javeriana.edu.co', TRUE, NOW(), 21, 'male',   'medium'),
  (2, 'nicolas',   'nicolas@javeriana.edu.co',   TRUE, NOW(), 22, 'male',   'low'),
  (3, 'juanjose',  'juanjose@javeriana.edu.co',  TRUE, NOW(), 21, 'male',   'high'),
  (4, 'laura',     'laura@javeriana.edu.co',     TRUE, NOW(), 20, 'female', 'low'),
  (5, 'sebastian', 'sebastian@javeriana.edu.co', TRUE, NOW(), 23, 'male',   'medium'),
  (6, 'cristian',  'cristian@javeriana.edu.co',  TRUE, NOW(), 22, 'male',   'none')
ON CONFLICT DO NOTHING;

SELECT setval('"user_user_id_seq"', 6);

-- ------------------------------------------------------------
-- PLAYERS (relación 1:1 con users para esta investigación)
-- ------------------------------------------------------------
INSERT INTO player (player_id, user_id, nickname) VALUES
  (1, 1, 'alejandro'),
  (2, 2, 'nicolas'),
  (3, 3, 'juanjose'),
  (4, 4, 'laura'),
  (5, 5, 'sebastian'),
  (6, 6, 'cristian')
ON CONFLICT DO NOTHING;

SELECT setval('player_player_id_seq', 6);

-- ------------------------------------------------------------
-- GAMES
-- Cada jugador tiene 3 partidas (una por mapa).
-- start_time / end_time se calculan del rango de timestamps
-- en los TSV: Map1 → 12:00–13:00, Map2 → 13:00–14:00,
--             Map3 → 14:00–16:20  (aprox.; 1200 tics cada uno)
-- ------------------------------------------------------------
INSERT INTO game
  (game_id, map_id, player_id, start_time, end_time, difficulty)
VALUES
  -- Alejandro (player 1)
  ( 1, 1, 1, '2026-01-01 12:00:00', '2026-01-01 12:19:59', 'hmp'),
  ( 2, 2, 1, '2026-01-01 12:20:00', '2026-01-01 12:39:59', 'hmp'),
  ( 3, 3, 1, '2026-01-01 12:40:00', '2026-01-01 16:19:59', 'hmp'),
  -- Nicolas (player 2)
  ( 4, 1, 2, '2026-01-01 12:00:00', '2026-01-01 12:19:59', 'hntr'),
  ( 5, 2, 2, '2026-01-01 12:20:00', '2026-01-01 12:39:59', 'hntr'),
  ( 6, 3, 2, '2026-01-01 12:40:00', '2026-01-01 16:19:59', 'hntr'),
  -- Juan José (player 3)
  ( 7, 1, 3, '2026-01-01 12:00:00', '2026-01-01 12:19:59', 'uv'),
  ( 8, 2, 3, '2026-01-01 12:20:00', '2026-01-01 12:39:59', 'uv'),
  ( 9, 3, 3, '2026-01-01 12:40:00', '2026-01-01 16:19:59', 'uv'),
  -- Laura (player 4)
  (10, 1, 4, '2026-01-01 12:00:00', '2026-01-01 12:19:59', 'itytd'),
  (11, 2, 4, '2026-01-01 12:20:00', '2026-01-01 12:39:59', 'itytd'),
  (12, 3, 4, '2026-01-01 12:40:00', '2026-01-01 16:19:59', 'itytd'),
  -- Sebastián (player 5)
  (13, 1, 5, '2026-01-01 12:00:00', '2026-01-01 12:19:59', 'hmp'),
  (14, 2, 5, '2026-01-01 12:20:00', '2026-01-01 12:39:59', 'hmp'),
  (15, 3, 5, '2026-01-01 12:40:00', '2026-01-01 16:19:59', 'hmp'),
  -- Cristian (player 6)
  (16, 1, 6, '2026-01-01 12:00:00', '2026-01-01 12:19:59', 'hntr'),
  (17, 2, 6, '2026-01-01 12:20:00', '2026-01-01 12:39:59', 'hntr'),
  (18, 3, 6, '2026-01-01 12:40:00', '2026-01-01 16:19:59', 'hntr')
ON CONFLICT DO NOTHING;

SELECT setval('game_game_id_seq', 18);

-- ============================================================
-- INSTRUMENTO UX: BANGS
-- (Basic Needs in Games Scale — Przybylski et al., open access)
-- 3 subescalas: Competence (C), Autonomy (A), Relatedness (R)
-- Escala Likert 1-7, 18 ítems en total
-- ============================================================

INSERT INTO ux_instrument (instrument_id, name, description, version) VALUES
  (1, 'BANGS',
   'Basic Needs in Games Scale. Mide satisfacción de necesidades psicológicas básicas (competencia, autonomía, relación) durante el juego. Escala Likert 1–7.',
   '1.0')
ON CONFLICT DO NOTHING;

SELECT setval('ux_instrument_instrument_id_seq', 1);

-- 18 ítems BANGS (traducidos al español para la aplicación)
-- Subescala C = Competence, A = Autonomy, R = Relatedness
INSERT INTO ux_item (item_id, instrument_id, question_text, response_type) VALUES
  -- Competencia (6 ítems)
  ( 1, 1, '[C1] Me sentí competente en el juego.',                          'likert7'),
  ( 2, 1, '[C2] Me sentí capaz de alcanzar mis objetivos en el juego.',     'likert7'),
  ( 3, 1, '[C3] Sentí que podía completar los desafíos del juego.',         'likert7'),
  ( 4, 1, '[C4] Pude superar los obstáculos que se me presentaron.',        'likert7'),
  ( 5, 1, '[C5] Sentí que dominé las habilidades necesarias para jugar.',   'likert7'),
  ( 6, 1, '[C6] El juego me permitió demostrar mis capacidades.',           'likert7'),
  -- Autonomía (6 ítems)
  ( 7, 1, '[A1] Sentí que podía elegir cómo jugar.',                        'likert7'),
  ( 8, 1, '[A2] Las acciones en el juego reflejaron mis propias decisiones.','likert7'),
  ( 9, 1, '[A3] Sentí libertad de explorar el juego a mi manera.',          'likert7'),
  (10, 1, '[A4] Pude tomar mis propias decisiones durante el juego.',       'likert7'),
  (11, 1, '[A5] El juego me permitió jugar de la forma que yo quería.',     'likert7'),
  (12, 1, '[A6] Me sentí libre de hacer lo que quisiera en el juego.',      'likert7'),
  -- Relación / Presencia social (6 ítems)
  (13, 1, '[R1] Sentí una conexión con los otros jugadores.',               'likert7'),
  (14, 1, '[R2] Me sentí cercano/a a los demás mientras jugaba.',           'likert7'),
  (15, 1, '[R3] Sentí que importaba lo que les pasaba a los demás jugadores.','likert7'),
  (16, 1, '[R4] Pude relacionarme bien con los otros jugadores.',           'likert7'),
  (17, 1, '[R5] Sentí que los otros jugadores se preocupaban por mí.',      'likert7'),
  (18, 1, '[R6] Sentí un vínculo con las personas con quienes jugué.',      'likert7')
ON CONFLICT DO NOTHING;

SELECT setval('ux_item_item_id_seq', 18);

-- ============================================================
-- RESPUESTAS UX  (una por usuario por juego — usamos game_id 3,6,9,12,15,18
-- que corresponden al último mapa jugado por cada jugador)
-- Valores sintéticos realistas en escala 1–7
-- ============================================================

INSERT INTO ux_response (response_id, user_id, instrument_id, game_id, submitted_at) VALUES
  (1, 1, 1,  3, '2026-01-01 16:25:00'),  -- alejandro
  (2, 2, 1,  6, '2026-01-01 16:26:00'),  -- nicolas
  (3, 3, 1,  9, '2026-01-01 16:27:00'),  -- juanjose
  (4, 4, 1, 12, '2026-01-01 16:28:00'),  -- laura
  (5, 5, 1, 15, '2026-01-01 16:29:00'),  -- sebastian
  (6, 6, 1, 18, '2026-01-01 16:30:00')   -- cristian
ON CONFLICT DO NOTHING;

SELECT setval('ux_response_response_id_seq', 6);

-- Respuestas por ítem (18 ítems × 6 usuarios = 108 filas)
-- Patrón: alejandro=alto, nicolas=medio-bajo, juanjose=muy alto,
--         laura=medio, sebastian=medio-alto, cristian=bajo
INSERT INTO ux_response_item (response_id, item_id, response_value) VALUES
  -- alejandro (response 1): competente, autónomo, social moderado
  (1,  1,'6'),(1,  2,'6'),(1,  3,'5'),(1,  4,'6'),(1,  5,'5'),(1,  6,'6'),
  (1,  7,'5'),(1,  8,'6'),(1,  9,'5'),(1, 10,'6'),(1, 11,'5'),(1, 12,'4'),
  (1, 13,'4'),(1, 14,'3'),(1, 15,'4'),(1, 16,'4'),(1, 17,'3'),(1, 18,'4'),
  -- nicolas (response 2): poca competencia, media autonomía
  (2,  1,'3'),(2,  2,'3'),(2,  3,'2'),(2,  4,'3'),(2,  5,'2'),(2,  6,'3'),
  (2,  7,'4'),(2,  8,'4'),(2,  9,'3'),(2, 10,'4'),(2, 11,'3'),(2, 12,'3'),
  (2, 13,'3'),(2, 14,'2'),(2, 15,'3'),(2, 16,'3'),(2, 17,'2'),(2, 18,'3'),
  -- juanjose (response 3): alto en todo
  (3,  1,'7'),(3,  2,'7'),(3,  3,'6'),(3,  4,'7'),(3,  5,'6'),(3,  6,'7'),
  (3,  7,'6'),(3,  8,'7'),(3,  9,'6'),(3, 10,'7'),(3, 11,'6'),(3, 12,'6'),
  (3, 13,'5'),(3, 14,'5'),(3, 15,'6'),(3, 16,'5'),(3, 17,'5'),(3, 18,'6'),
  -- laura (response 4): medio
  (4,  1,'4'),(4,  2,'4'),(4,  3,'4'),(4,  4,'5'),(4,  5,'3'),(4,  6,'4'),
  (4,  7,'4'),(4,  8,'5'),(4,  9,'4'),(4, 10,'4'),(4, 11,'4'),(4, 12,'3'),
  (4, 13,'4'),(4, 14,'4'),(4, 15,'4'),(4, 16,'4'),(4, 17,'3'),(4, 18,'4'),
  -- sebastian (response 5): medio-alto
  (5,  1,'5'),(5,  2,'5'),(5,  3,'5'),(5,  4,'6'),(5,  5,'4'),(5,  6,'5'),
  (5,  7,'5'),(5,  8,'6'),(5,  9,'5'),(5, 10,'5'),(5, 11,'5'),(5, 12,'4'),
  (5, 13,'5'),(5, 14,'4'),(5, 15,'5'),(5, 16,'5'),(5, 17,'4'),(5, 18,'5'),
  -- cristian (response 6): bajo
  (6,  1,'2'),(6,  2,'2'),(6,  3,'2'),(6,  4,'3'),(6,  5,'2'),(6,  6,'2'),
  (6,  7,'3'),(6,  8,'3'),(6,  9,'2'),(6, 10,'3'),(6, 11,'2'),(6, 12,'2'),
  (6, 13,'2'),(6, 14,'2'),(6, 15,'2'),(6, 16,'2'),(6, 17,'1'),(6, 18,'2')
ON CONFLICT DO NOTHING;
