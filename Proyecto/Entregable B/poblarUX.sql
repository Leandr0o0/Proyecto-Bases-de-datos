-- ============================================================
--  Datos semilla:
--    - Instrumento PENS (21 ítems, escala Likert 1-7)
--    - Episodios, Mapas y Sectores (3 episodios, 9 mapas)
--    - Usuarios y Jugadores (8 usuarios, 8 jugadores)
-- ============================================================

-- ── UX INSTRUMENT: PENS ──────────────────────────────────────
-- Player Experience of Need Satisfaction (Ryan et al., 2006)
-- Mide: Competence, Autonomy, Relatedness, Presence/Immersion, Intuitive Controls
INSERT INTO ux_instrument (name, description, version) VALUES
(
  'PENS',
  'Player Experience of Need Satisfaction. Evaluates whether gameplay satisfies '
  'psychological needs: competence, autonomy, relatedness, presence/immersion, '
  'and intuitive controls. Items rated 1–7 (1=strongly disagree, 7=strongly agree).',
  '1.0'
);

-- Ítems PENS (21 ítems reales del instrumento)

INSERT INTO ux_item (instrument_id, question_text, response_type) VALUES
-- Competence (6 ítems)
(1, '[COMP] I feel competent at the game.',                                  'likert'),
(1, '[COMP] I felt very capable and effective when playing.',                'likert'),
(1, '[COMP] My ability to play the game well made me feel good.',            'likert'),
(1, '[COMP] I did not feel very skilled at this game. (R)',                  'likert'),
(1, '[COMP] The game was a great match for my skill level.',                 'likert'),
(1, '[COMP] I felt very accomplished when playing this game.',               'likert'),
-- Autonomy (4 ítems)
(1, '[AUTO] I experienced a lot of freedom in the game.',                    'likert'),
(1, '[AUTO] I felt like I could play the game my way.',                      'likert'),
(1, '[AUTO] There was not much opportunity for me to decide how to play. (R)','likert'),
(1, '[AUTO] I felt free to play the game in my own way.',                    'likert'),
-- Relatedness (4 ítems)
(1, '[REL] I found the game characters interesting.',                        'likert'),
(1, '[REL] I felt close to the game characters.',                            'likert'),
(1, '[REL] The game gave me the opportunity to care about characters.',      'likert'),
(1, '[REL] I did not feel the characters in the game were very interesting. (R)','likert'),
-- Presence/Immersion (4 ítems)
(1, '[PRES] When playing the game I felt like I was in the game world.',     'likert'),
(1, '[PRES] I was immersed in the game world.',                              'likert'),
(1, '[PRES] Playing the game felt like being somewhere else.',               'likert'),
(1, '[PRES] The game world felt real to me.',                                'likert'),
-- Intuitive Controls (3 ítems)
(1, '[INT] The game controls were easy to learn.',                           'likert'),
(1, '[INT] I was able to use the game controls without thinking about them.','likert'),
(1, '[INT] The controls for this game were intuitive and natural.',          'likert');

-- ── EPISODES ─────────────────────────────────────────────────
INSERT INTO episode (name, description) VALUES
('Knee-Deep in the Dead',
 'Episode 1 of Doom. Set in a military base on Phobos, moon of Mars.'),
('The Shores of Hell',
 'Episode 2 of Doom. Set in a deeper complex on Phobos, overrun by demons.'),
('Inferno',
 'Episode 3 of Doom. The final episode, set in Hell itself.');

-- ── MAPS ─────────────────────────────────────────────────────
-- 3 mapas por episodio = 9 mapas totales
INSERT INTO map (episode_id, map_code, map_name) VALUES
-- Episodio 1
(1, 'E1M1', 'Hangar'),
(1, 'E1M2', 'Nuclear Plant'),
(1, 'E1M3', 'Toxin Refinery'),
-- Episodio 2
(2, 'E2M1', 'Deimos Anomaly'),
(2, 'E2M2', 'Containment Area'),
(2, 'E2M3', 'Refinery'),
-- Episodio 3
(3, 'E3M1', 'Hell Keep'),
(3, 'E3M2', 'Slough of Despair'),
(3, 'E3M3', 'Pandemonium');

-- ── SECTORS ──────────────────────────────────────────────────
-- Cada mapa tiene 6 sectores (celdas 250×250 unidades)
-- Nombrados como map_code + coordenada de grilla
INSERT INTO sector (map_id, sector_name)
SELECT m.map_id, m.map_code || '_S' || s.n
FROM map m
CROSS JOIN (
    SELECT 1 AS n UNION SELECT 2 UNION SELECT 3
    UNION SELECT 4 UNION SELECT 5 UNION SELECT 6
) s;
-- Total: 9 mapas × 6 sectores = 54 sectores

-- ── USERS ────────────────────────────────────────────────────
INSERT INTO "user" (username, email, consent_given, consent_date) VALUES
('alejandro_m', 'alejandro@uni.edu.co',  TRUE,  '2025-03-01 08:00:00'),
('laura_r',     'laura@uni.edu.co',      TRUE,  '2025-03-01 08:05:00'),
('nicolas_e',   'nicolas@uni.edu.co',    TRUE,  '2025-03-01 08:10:00'),
('juanjo_c',    'juanjo@uni.edu.co',     TRUE,  '2025-03-01 08:15:00'),
('sofia_v',     'sofia@uni.edu.co',      TRUE,  '2025-03-01 09:00:00'),
('camilo_t',    'camilo@uni.edu.co',     TRUE,  '2025-03-01 09:05:00'),
('valeria_g',   'valeria@uni.edu.co',    FALSE, NULL),
('daniel_o',    'daniel@uni.edu.co',     TRUE,  '2025-03-01 09:20:00');

-- ── PLAYERS ──────────────────────────────────────────────────
-- Un jugador por usuario + dos jugadores anónimos extra
INSERT INTO player (user_id, nickname) VALUES
(1, 'DoomSlayer_AM'),
(2, 'GunnerLaura'),
(3, 'NicoBlast'),
(4, 'JJCastle'),
(5, 'SofiaRip'),
(6, 'CamTear'),
(7, 'ValGhost'),
(8, 'DanielX'),
(NULL, 'AnonRookie'),   -- jugador anónimo 1
(NULL, 'AnonHero');     -- jugador anónimo 2