#!/usr/bin/env python3
"""
generate_data.py
Genera datos sintéticos para el proyecto Doom Telemetry:
  - Partidas (games): una por jugador × mapa seleccionado
  - Telemetría: ≥ 20 000 filas (aprox. 35 tics/s × duración)
  - Respuestas UX: una respuesta PENS completa por partida (jugadores con user)
  - Archivo TSV para cargar vía staging
  - Archivo SQL con INSERT de games, ux_instrument, ux_item y ux_responses

Ejecutar: python3 generate_data.py
Salida  : telemetry_raw.tsv
          04_games_and_ux.sql

Cambios respecto al original:
  - Rutas de salida relativas (ya no hardcodeadas a Windows)
  - Jugadores limitados a 1-8 (consistente con el DDL)
  - Columna 'score' eliminada del INSERT de game (no existe en el DDL)
  - score movido a game_participant (donde sí existe)
  - ammo limitado a 200 (consistente con el dominio del juego)
  - Agregado INSERT de ux_instrument (PENS) y sus 21 ítems oficiales
    antes de los INSERT de ux_response
"""

import argparse
import random
import math
import csv
import os
from datetime import datetime, timedelta

random.seed(42)

# ── CLI ────────────────────────────────────────────────────────────────────────
parser = argparse.ArgumentParser(description="Genera datos sintéticos para Doom Telemetry")
parser.add_argument("--tsv", default="telemetry_raw.tsv",  help="Ruta del TSV de salida")
parser.add_argument("--sql", default="04_games_and_ux.sql", help="Ruta del SQL de salida")
args = parser.parse_args()

OUT_TSV = args.tsv
OUT_SQL = args.sql

# ── Jugadores (solo 1-8, consistente con el DDL) ───────────────────────────────
# player_id → user_id (None si anónimo)
# CORRECCIÓN: eliminados players 9 y 10 que no existen en la BD
PLAYERS = {
    1: 1, 2: 2, 3: 3, 4: 4,
    5: 5, 6: 6, 7: 7, 8: 8,
}

# ── Helpers de mapa/sector ─────────────────────────────────────────────────────
def sectors_for_map(map_id):
    """sector_ids: para map_id X, sectores son (X-1)*6+1 ... X*6"""
    base = (map_id - 1) * 6 + 1
    return list(range(base, base + 6))

MAPS        = list(range(1, 10))   # map_id 1..9
DIFFICULTIES = ['easy', 'medium', 'hard', 'nightmare']
MAP_SIZE    = 1500.0               # x,y en [0, 1500] — 6 sectores de 250 unidades

# ── Física sintética del jugador ───────────────────────────────────────────────
def next_pos(x, y, z, angle, momx, momy):
    """Simula movimiento realista con dirección + perturbación."""
    angle += random.gauss(0, 0.05)
    speed  = max(0, random.gauss(6, 2))
    momx   = math.cos(angle) * speed + random.gauss(0, 0.5)
    momy   = math.sin(angle) * speed + random.gauss(0, 0.5)
    x     += momx
    y     += momy
    # Rebotar en bordes del mapa
    if x < 0:        x, momx =        0,  abs(momx)
    if x > MAP_SIZE: x, momx = MAP_SIZE, -abs(momx)
    if y < 0:        y, momy =        0,  abs(momy)
    if y > MAP_SIZE: y, momy = MAP_SIZE, -abs(momy)
    z = max(0.0, min(128.0, z + random.gauss(0, 0.3)))
    return x, y, z, angle, momx, momy

def sector_for_pos(x, y, map_id):
    """Asigna sector según posición en grilla 2×3."""
    col = int(x // 750)        # 0 o 1
    row = int(y // 500)        # 0, 1 o 2
    idx = max(0, min(5, row * 2 + col))
    return sectors_for_map(map_id)[idx]

def random_stat(prev, lo, hi, delta=5):
    """Estadística que varía suavemente."""
    return max(lo, min(hi, prev + random.randint(-delta, delta)))

# ── Definir partidas ───────────────────────────────────────────────────────────
# Cada jugador juega en 3 mapas (uno por episodio) → 8×3 = 24 games
# Con ~35 tics/s y 90-180 s de duración → ~94 000-189 000 tics totales (>20 000)
games      = []
base_start = datetime(2025, 3, 10, 9, 0, 0)
game_id    = 1

for player_id in PLAYERS:                      # players 1..8
    for ep in range(3):                         # un mapa por episodio
        map_id     = ep * 3 + random.randint(1, 3)
        difficulty = random.choice(DIFFICULTIES)
        duration_s = random.randint(90, 180)
        start      = base_start + timedelta(hours=(game_id - 1) * 0.4)
        end        = start + timedelta(seconds=duration_s)
        # CORRECCIÓN: 'score' eliminado — no existe en la tabla game del DDL
        #             se guarda en game_participant (ver SQL generado abajo)
        score      = random.randint(0, 5000)    # se usa solo en game_participant
        games.append({
            'game_id':    game_id,
            'map_id':     map_id,
            'player_id':  player_id,
            'start_time': start,
            'end_time':   end,
            'difficulty': difficulty,
            'score':      score,               # solo para game_participant
            'tics':       duration_s * 35,
        })
        game_id += 1

total_tics = sum(g['tics'] for g in games)
print(f"Partidas definidas : {len(games)}")
print(f"Tics esperados     : {total_tics:,}")

# ── Generar TSV de telemetría ──────────────────────────────────────────────────
os.makedirs(os.path.dirname(OUT_TSV) or '.', exist_ok=True)

header    = ['game_id', 'player_id', 'sector_id', 'tic', 'timestamp',
             'x', 'y', 'z', 'angle', 'momx', 'momy', 'health', 'armor', 'ammo']
row_count = 0

with open(OUT_TSV, 'w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f, delimiter='\t')
    writer.writerow(header)

    for g in games:
        gid     = g['game_id']
        pid     = g['player_id']
        mid     = g['map_id']
        n_tics  = g['tics']
        t_start = g['start_time']

        x      = random.uniform(50, MAP_SIZE - 50)
        y      = random.uniform(50, MAP_SIZE - 50)
        z      = 0.0
        angle  = random.uniform(0, 2 * math.pi)
        momx   = 0.0
        momy   = 0.0
        health = 100
        armor  = 50
        ammo   = 200

        for tic in range(n_tics):
            x, y, z, angle, momx, momy = next_pos(x, y, z, angle, momx, momy)
            sid = sector_for_pos(x, y, mid)
            ts  = t_start + timedelta(seconds=tic / 35.0)

            health = random_stat(health, 0, 200, delta=2)
            armor  = random_stat(armor,  0, 200, delta=1)
            # CORRECCIÓN: ammo limitado a 200 (dominio del juego)
            ammo   = random_stat(ammo,   0, 200, delta=3)

            writer.writerow([
                gid, pid, sid, tic,
                ts.strftime('%Y-%m-%d %H:%M:%S.%f'),
                f'{x:.4f}', f'{y:.4f}', f'{z:.4f}',
                f'{angle:.6f}', f'{momx:.4f}', f'{momy:.4f}',
                health, armor, ammo,
            ])
            row_count += 1

print(f"Filas TSV generadas: {row_count:,}")

# ── Generar SQL ────────────────────────────────────────────────────────────────
# PENS — Player Experience of Need Satisfaction (21 ítems oficiales, Likert 1-7)
# Ryan, R.M., Rigby, C.S. & Przybylski, A. (2006). Mot. Emot. 30, 347–363.
PENS_ITEMS = [
    # Competence (7 ítems)
    (1,  "I feel competent at the game."),
    (2,  "I feel very capable and effective when playing."),
    (3,  "My ability to play the game is well matched to the game's challenges."),
    (4,  "I feel a sense of accomplishment from playing."),
    (5,  "I find the game too difficult."),          # reverse-scored
    (6,  "I do not feel very skilled at this game."), # reverse-scored
    (7,  "The game is too easy for me."),             # reverse-scored
    # Autonomy (7 ítems)
    (8,  "I experience a lot of freedom in the game."),
    (9,  "I feel like I can play the game my own way."),
    (10, "I feel free to play the game how I choose."),
    (11, "There is not much opportunity for me to decide for myself how to play."), # reverse
    (12, "I feel pressured while playing."),           # reverse
    (13, "The game tries to force me to play in ways I do not want to."),          # reverse
    (14, "I play the game in a way that reflects who I am."),
    # Relatedness (7 ítems)
    (15, "I feel close to the other players."),
    (16, "I find the interactions with other players rewarding."),
    (17, "I do not feel connected to others playing the game."),  # reverse
    (18, "The people I interact with in the game do not seem to care about me."),  # reverse
    (19, "I feel like I know the people I play with."),
    (20, "I find the relationships I have with others in this game important."),
    (21, "I feel detached from other players."),      # reverse
]

lines = []
lines.append('-- ============================================================')
lines.append('--  04_games_and_ux.sql')
lines.append('--  Orden correcto de inserción (respeta todas las FK):')
lines.append('--  episode → map → sector → user → player →')
lines.append('--  ux_instrument → ux_item → game → game_participant →')
lines.append('--  ux_response → ux_response_item')
lines.append('--  Generado por generate_data.py')
lines.append('-- ============================================================')
lines.append('')

# ── episode (padre de map) ─────────────────────────────────────────────────────
lines.append('-- ── EPISODES ───────────────────────────────────────────────')
lines.append('INSERT INTO episode (episode_id, name, description) VALUES')
lines.append("(1, 'Knee-Deep in the Dead', 'Classic UAC base levels'),")
lines.append("(2, 'The Shores of Hell',    'Deimos moon base'),")
lines.append("(3, 'Inferno',               'Hell itself')")
lines.append('ON CONFLICT DO NOTHING;')
lines.append("SELECT setval('episode_episode_id_seq', 3);")
lines.append('')

# ── map (padre de sector y game) ──────────────────────────────────────────────
lines.append('-- ── MAPS ───────────────────────────────────────────────────')
lines.append('INSERT INTO map (map_id, episode_id, map_code, map_name) VALUES')
map_rows = [
    "(1, 1, 'E1M1', 'Hangar')",
    "(2, 1, 'E1M2', 'Nuclear Plant')",
    "(3, 1, 'E1M3', 'Toxin Refinery')",
    "(4, 2, 'E2M1', 'Deimos Anomaly')",
    "(5, 2, 'E2M2', 'Containment Area')",
    "(6, 2, 'E2M3', 'Refinery')",
    "(7, 3, 'E3M1', 'Hell Keep')",
    "(8, 3, 'E3M2', 'Slough of Despair')",
    "(9, 3, 'E3M3', 'Pandemonium')",
]
lines.append(',\n'.join(map_rows))
lines.append('ON CONFLICT DO NOTHING;')
lines.append("SELECT setval('map_map_id_seq', 9);")
lines.append('')

# ── sector (padre de telemetry_event) ─────────────────────────────────────────
lines.append('-- ── SECTORS (6 por mapa, 54 en total) ─────────────────────')
lines.append('INSERT INTO sector (sector_id, map_id, sector_name) VALUES')
sector_rows = []
for mid in range(1, 10):
    for i in range(6):
        sid = (mid - 1) * 6 + 1 + i
        sector_rows.append(f"({sid}, {mid}, 'Sector-{mid}-{i+1}')")
lines.append(',\n'.join(sector_rows))
lines.append('ON CONFLICT DO NOTHING;')
lines.append("SELECT setval('sector_sector_id_seq', 54);")
lines.append('')

# ── user (padre de player y ux_response) ──────────────────────────────────────
lines.append('-- ── USERS ──────────────────────────────────────────────────')
lines.append('INSERT INTO "user" (user_id, username, email, consent_given, consent_date) VALUES')
user_rows = [
    f"({i}, 'user_{i:02d}', 'user{i:02d}@javeriana.edu.co', TRUE, '2026-01-{9+i:02d}')"
    for i in range(1, 9)
]
lines.append(',\n'.join(user_rows))
lines.append('ON CONFLICT DO NOTHING;')
lines.append("SELECT setval('user_user_id_seq', 8);")
lines.append('')

# ── player (padre de game y game_participant) ──────────────────────────────────
lines.append('-- ── PLAYERS ─────────────────────────────────────────────────')
lines.append('INSERT INTO player (player_id, user_id, nickname) VALUES')
player_rows = [
    f"({i}, {i}, 'player_{i:02d}')"
    for i in range(1, 9)
]
lines.append(',\n'.join(player_rows))
lines.append('ON CONFLICT DO NOTHING;')
lines.append("SELECT setval('player_player_id_seq', 8);")
lines.append('')

# ── ux_instrument ──────────────────────────────────────────────────────────────
lines.append('-- ── UX INSTRUMENT (PENS) ──────────────────────────────────')
lines.append("INSERT INTO ux_instrument (instrument_id, name, description, version) VALUES")
lines.append("(1, 'PENS', 'Player Experience of Need Satisfaction — Ryan et al. (2006)', '1.0')")
lines.append("ON CONFLICT DO NOTHING;")
lines.append("SELECT setval('ux_instrument_instrument_id_seq', 1);")
lines.append('')

# ── ux_item (21 ítems PENS oficiales) ─────────────────────────────────────────
lines.append('-- ── UX ITEMS (PENS, 21 ítems) ─────────────────────────────')
lines.append('INSERT INTO ux_item (item_id, instrument_id, question_text, response_type) VALUES')
item_rows = [
    f"({iid}, 1, '{text.replace(chr(39), chr(39)+chr(39))}', 'likert')"
    for iid, text in PENS_ITEMS
]
lines.append(',\n'.join(item_rows) + ';')
lines.append("SELECT setval('ux_item_item_id_seq', 21);")
lines.append('')

# ── games ──────────────────────────────────────────────────────────────────────
# CORRECCIÓN: columna 'score' eliminada — no existe en la tabla game del DDL
lines.append('-- ── GAMES ──────────────────────────────────────────────────')
lines.append('INSERT INTO game (game_id, map_id, player_id, start_time, end_time, difficulty) VALUES')
game_rows = []
for g in games:
    game_rows.append(
        f"({g['game_id']}, {g['map_id']}, {g['player_id']}, "
        f"'{g['start_time'].strftime('%Y-%m-%d %H:%M:%S')}', "
        f"'{g['end_time'].strftime('%Y-%m-%d %H:%M:%S')}', "
        f"'{g['difficulty']}')"
    )
lines.append(',\n'.join(game_rows) + ';')
lines.append(f"SELECT setval('game_game_id_seq', {len(games)});")
lines.append('')

# ── game_participant (aquí sí va score) ────────────────────────────────────────
lines.append('-- ── GAME_PARTICIPANT (score va aquí, no en game) ───────────')
lines.append('INSERT INTO game_participant (game_id, player_id, role, score) VALUES')
gp_rows = [
    f"({g['game_id']}, {g['player_id']}, 'player', {g['score']})"
    for g in games
]
lines.append(',\n'.join(gp_rows) + ';')
lines.append('')

# ── ux_response + ux_response_item ────────────────────────────────────────────
lines.append('-- ── UX RESPONSES (PENS, 21 ítems Likert 1-7) ──────────────')
lines.append('-- Solo para jugadores con user_id (no anónimos)')
lines.append('')

resp_id       = 1
resp_item_id  = 1
response_rows = []
response_item_rows = []

for g in games:
    uid = PLAYERS[g['player_id']]
    if uid is None:
        continue

    submitted = g['end_time'] + timedelta(minutes=random.randint(2, 10))
    response_rows.append(
        f"({resp_id}, {uid}, 1, {g['game_id']}, "
        f"'{submitted.strftime('%Y-%m-%d %H:%M:%S')}')"
    )
    for item_id in range(1, 22):
        score = random.randint(1, 7)
        response_item_rows.append(
            f"({resp_item_id}, {resp_id}, {item_id}, '{score}')"
        )
        resp_item_id += 1
    resp_id += 1

lines.append('INSERT INTO ux_response (response_id, user_id, instrument_id, game_id, submitted_at) VALUES')
lines.append(',\n'.join(response_rows) + ';')
lines.append(f"SELECT setval('ux_response_response_id_seq', {resp_id - 1});")
lines.append('')
lines.append('INSERT INTO ux_response_item (response_item_id, response_id, item_id, response_value) VALUES')
lines.append(',\n'.join(response_item_rows) + ';')
lines.append(f"SELECT setval('ux_response_item_response_item_id_seq', {resp_item_id - 1});")

os.makedirs(os.path.dirname(OUT_SQL) or '.', exist_ok=True)
with open(OUT_SQL, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))

print(f"Respuestas UX      : {resp_id - 1} respuestas, {resp_item_id - 1} ítems")
print(f"SQL generado       : {OUT_SQL}")
print(f"TSV generado       : {OUT_TSV}")
print("¡Listo!")
