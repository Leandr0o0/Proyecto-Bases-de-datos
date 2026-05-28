#!/usr/bin/env python3
"""
generate_data.py
Genera datos sintéticos para el proyecto Doom Telemetry:
  - Partidas (games): una por jugador × mapa seleccionado
  - Telemetría: ≥ 20 000 filas (aprox. 35 tics/s × duración)
  - Respuestas UX: una respuesta PENS completa por partida (si el jugador tiene user)
  - Archivo TSV para cargar vía staging

Ejecutar: python3 generate_data.py
Salida  : doom_project/data/telemetry_raw.tsv
          doom_project/sql/04_games_and_ux.sql
"""

import random
import math
import csv
import os
from datetime import datetime, timedelta

random.seed(42)

# ── Configuración ──────────────────────────────────────────────
OUT_TSV  = r'C:\Users\Laura Rueda\Escritorio\Javeriana\Tercer semestre\Bases de datos\Proyecto\ENTREGA_B\telemetry_raw.tsv'
OUT_SQL  = r'C:\Users\Laura Rueda\Escritorio\Javeriana\Tercer semestre\Bases de datos\Proyecto\ENTREGA_B\04_games_and_ux.sql'

# player_id  → user_id (None si anónimo)
PLAYERS = {
    1: 1, 2: 2, 3: 3, 4: 4, 5: 5,
    6: 6, 7: 7, 8: 8,
    9: None, 10: None
}

# map_id → (episode_id, map_code, sector_ids_start)
# sector_ids: para map_id X, sectores son (X-1)*6+1 ... X*6
def sectors_for_map(map_id):
    base = (map_id - 1) * 6 + 1
    return list(range(base, base + 6))

MAPS = list(range(1, 10))   # map_id 1..9

DIFFICULTIES = ['easy', 'medium', 'hard', 'nightmare']

# Área de mapa: x,y en [0, 1500] (6 sectores de 250 unidades)
MAP_SIZE = 1500.0

# ── Física sintética del jugador ───────────────────────────────
def next_pos(x, y, z, angle, momx, momy):
    """Simula movimiento realista con dirección + perturbación."""
    # Girar ligeramente
    angle += random.gauss(0, 0.05)
    # Velocidad base
    speed = random.gauss(6, 2)
    speed = max(0, speed)
    momx = math.cos(angle) * speed + random.gauss(0, 0.5)
    momy = math.sin(angle) * speed + random.gauss(0, 0.5)
    x += momx
    y += momy
    # Rebotar en bordes del mapa
    if x < 0:   x, momx = 0,        abs(momx)
    if x > MAP_SIZE: x, momx = MAP_SIZE, -abs(momx)
    if y < 0:   y, momy = 0,        abs(momy)
    if y > MAP_SIZE: y, momy = MAP_SIZE, -abs(momy)
    z = max(0.0, min(128.0, z + random.gauss(0, 0.3)))
    return x, y, z, angle, momx, momy

def sector_for_pos(x, y, map_id):
    """Asigna sector según posición en grilla 2×3."""
    col = int(x // 750)   # 0 o 1
    row = int(y // 500)   # 0, 1 o 2
    idx = row * 2 + col   # 0..5
    idx = max(0, min(5, idx))
    return sectors_for_map(map_id)[idx]

def random_stat(prev, lo, hi, delta=5):
    """Estadística que varía suavemente."""
    v = prev + random.randint(-delta, delta)
    return max(lo, min(hi, v))

# ── Definir partidas ──────────────────────────────────────────
# Cada jugador juega en 3 mapas (uno por episodio) → 10×3 = 30 games
# Duración variable para superar 20k tics en total
games = []
base_start = datetime(2025, 3, 10, 9, 0, 0)

game_id = 1
for player_id in range(1, 11):         # players 1..10
    for ep in range(3):                # un mapa por episodio
        map_id = ep * 3 + random.randint(1, 3)   # aleatorio dentro del episodio
        difficulty = random.choice(DIFFICULTIES)
        duration_s = random.randint(90, 180)      # 90-180 segundos
        start = base_start + timedelta(hours=(game_id - 1) * 0.4)
        end   = start + timedelta(seconds=duration_s)
        score = random.randint(0, 5000)
        games.append({
            'game_id': game_id,
            'map_id': map_id,
            'player_id': player_id,
            'start_time': start,
            'end_time': end,
            'difficulty': difficulty,
            'score': score,
            'tics': duration_s * 35,   # 35 tics/segundo
        })
        game_id += 1

total_tics = sum(g['tics'] for g in games)
print(f"Partidas definidas : {len(games)}")
print(f"Tics esperados     : {total_tics:,}")

# ── Generar TSV de telemetría ──────────────────────────────────
os.makedirs('/home/claude/doom_project/data', exist_ok=True)

header = ['game_id','player_id','sector_id','tic','timestamp',
          'x','y','z','angle','momx','momy','health','armor','ammo']

row_count = 0
with open(OUT_TSV, 'w', newline='') as f:
    writer = csv.writer(f, delimiter='\t')
    writer.writerow(header)

    for g in games:
        gid      = g['game_id']
        pid      = g['player_id']
        mid      = g['map_id']
        n_tics   = g['tics']
        t_start  = g['start_time']

        # Estado inicial del jugador
        x     = random.uniform(50, MAP_SIZE - 50)
        y     = random.uniform(50, MAP_SIZE - 50)
        z     = 0.0
        angle = random.uniform(0, 2 * math.pi)
        momx  = 0.0
        momy  = 0.0
        health = 100
        armor  = 50
        ammo   = 200

        for tic in range(n_tics):
            x, y, z, angle, momx, momy = next_pos(x, y, z, angle, momx, momy)
            sid = sector_for_pos(x, y, mid)
            ts  = t_start + timedelta(seconds=tic / 35.0)

            health = random_stat(health, 0, 200, delta=2)
            armor  = random_stat(armor,  0, 200, delta=1)
            ammo   = random_stat(ammo,   0, 400, delta=3)

            writer.writerow([
                gid, pid, sid, tic,
                ts.strftime('%Y-%m-%d %H:%M:%S.%f'),
                f'{x:.4f}', f'{y:.4f}', f'{z:.4f}',
                f'{angle:.6f}', f'{momx:.4f}', f'{momy:.4f}',
                health, armor, ammo
            ])
            row_count += 1

print(f"Filas TSV generadas: {row_count:,}")

# ── Generar SQL: GAMES + UX_RESPONSES ─────────────────────────
lines = []
lines.append('-- ============================================================')
lines.append('--  poblarGame.sql')
lines.append('--  Partidas sintéticas + respuestas PENS')
lines.append('-- ============================================================')
lines.append('')
lines.append('-- ── GAMES ──────────────────────────────────────────────────')
lines.append('INSERT INTO game (game_id, map_id, player_id, start_time, end_time, difficulty, score) VALUES')

game_rows = []
for g in games:
    game_rows.append(
        f"({g['game_id']}, {g['map_id']}, {g['player_id']}, "
        f"'{g['start_time'].strftime('%Y-%m-%d %H:%M:%S')}', "
        f"'{g['end_time'].strftime('%Y-%m-%d %H:%M:%S')}', "
        f"'{g['difficulty']}', {g['score']})"
    )
lines.append(',\n'.join(game_rows) + ';')

# Ajustar secuencia SERIAL
lines.append(f"\nSELECT setval('game_game_id_seq', {len(games)});")

lines.append('')
lines.append('-- ── UX RESPONSES (PENS, 21 ítems Likert 1-7) ──────────────')
lines.append('-- Solo para jugadores con user_id (no anónimos)')
lines.append('')

resp_id = 1
resp_item_id = 1
response_rows = []
response_item_rows = []

for g in games:
    uid = PLAYERS[g['player_id']]
    if uid is None:
        continue  # anónimos no tienen user, saltar

    submitted = g['end_time'] + timedelta(minutes=random.randint(2, 10))
    response_rows.append(
        f"({resp_id}, {uid}, 1, {g['game_id']}, "
        f"'{submitted.strftime('%Y-%m-%d %H:%M:%S')}')"
    )

    # 21 ítems PENS (item_id 1..21)
    for item_id in range(1, 22):
        score = random.randint(1, 7)
        response_item_rows.append(
            f"({resp_item_id}, {resp_id}, {item_id}, '{score}')"
        )
        resp_item_id += 1
    resp_id += 1

lines.append('INSERT INTO ux_response (response_id, user_id, instrument_id, game_id, submitted_at) VALUES')
lines.append(',\n'.join(response_rows) + ';')
lines.append(f"\nSELECT setval('ux_response_response_id_seq', {resp_id - 1});")

lines.append('')
lines.append('INSERT INTO ux_response_item (response_item_id, response_id, item_id, response_value) VALUES')
lines.append(',\n'.join(response_item_rows) + ';')
lines.append(f"\nSELECT setval('ux_response_item_response_item_id_seq', {resp_item_id - 1});")

with open(OUT_SQL, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))

print(f"Respuestas UX      : {resp_id - 1} respuestas, {resp_item_id - 1} ítems")
print(f"SQL generado       : {OUT_SQL}")
print(f"TSV generado       : {OUT_TSV}")
print("¡Listo!")
