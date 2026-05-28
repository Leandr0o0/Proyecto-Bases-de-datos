"""
02_etl_load.py
Pipeline ETL completo para el proyecto Telemetry & UX.

Pasos:
  1. Siembra tablas de referencia (user, player, episode, map, sector, game,
     game_participant, ux_instrument, ux_item).
  2. Carga el TSV a telemetry_staging via COPY.
  3. Transforma staging → telemetry_event (cast, dedup, validación).
  4. Registra filas rechazadas en etl_error_log.

Uso:
    python 03_etl_load.py                         # valores por defecto
    python 03_etl_load.py --tsv otra.tsv          # TSV alternativo
    python 03_etl_load.py --db doom_db            # base de datos distinta

Requisitos:
    pip install psycopg2-binary
    La base de datos debe existir y el DDL (01_ddl_completo.sql) debe
    haberse ejecutado antes de correr este script.
"""

import argparse
import io
import sys
from datetime import datetime, timedelta
import random
import psycopg2
from psycopg2.extras import execute_values

# ── Configuración de conexión ─────────────────────────────────────────────────
DEFAULT_DSN = {
    "host":     "localhost",
    "port":     5432,
    "dbname":   "doom_v2",
    "user":     "postgres",
    "password": "postgres",
}

# ── Datos de referencia (deben coincidir con 02_generate_tsv.py) ──────────────

EPISODES = [
    (1, "Knee-Deep in the Dead",  "Classic UAC base levels"),
    (2, "The Shores of Hell",     "Deimos moon base"),
    (3, "Inferno",                "Hell itself"),
]

MAPS = [
    (1, 1, "E1M1", "Hangar"),
    (2, 1, "E1M2", "Nuclear Plant"),
    (3, 1, "E1M3", "Toxin Refinery"),
    (4, 2, "E2M1", "Deimos Anomaly"),
    (5, 2, "E2M2", "Containment Area"),
    (6, 2, "E2M3", "Refinery"),
    (7, 3, "E3M1", "Hell Keep"),
    (8, 3, "E3M2", "Slough of Despair"),
    (9, 3, "E3M3", "Pandemonium"),
]

# 6 sectores por mapa → 54 sectores en total
SECTORS = [
    (map_id * 6 - 5 + i, map_id, f"Sector-{map_id}-{i+1}")
    for map_id in range(1, 10)
    for i in range(6)
]

USERS = [
    (i, f"user_{i:02d}", f"user{i:02d}@javeriana.edu.co", True,
     datetime(2026, 1, 10) + timedelta(days=i))
    for i in range(1, 9)
]

PLAYERS = [
    (i, i, f"player_{i:02d}")          # player_id = user_id (1:1 en este dataset)
    for i in range(1, 9)
]

DIFFICULTIES = ["easy", "medium", "hard", "nightmare"]

# Instrumento UX: BANGS (Basic Needs in Games Scale) — open-access
UX_INSTRUMENT = (1, "BANGS", "Basic Needs in Games Scale — open-access UX instrument", "1.0")

UX_ITEMS = [
    # (item_id, instrument_id, question_text, response_type)
    (1,  1, "Playing this game makes me feel competent.",                      "likert"),
    (2,  1, "I feel like I can accomplish challenging things in this game.",    "likert"),
    (3,  1, "I feel a sense of mastery while playing.",                        "likert"),
    (4,  1, "I feel free to play the game in my own way.",                     "likert"),
    (5,  1, "I can choose how I want to play.",                                "likert"),
    (6,  1, "I feel like I have control over my own choices in the game.",     "likert"),
    (7,  1, "I feel connected to other players in the game.",                  "likert"),
    (8,  1, "I feel like I belong to a community when playing.",               "likert"),
    (9,  1, "Playing this game helps me feel close to others.",                "likert"),
    (10, 1, "Overall, I find this game enjoyable.",                            "likert"),
]


# ── Helpers ───────────────────────────────────────────────────────────────────

def connect(dsn: dict):
    try:
        conn = psycopg2.connect(**dsn)
        conn.autocommit = False
        return conn
    except psycopg2.OperationalError as e:
        print(f"[ERROR] No se pudo conectar a la base de datos: {e}")
        print("        Verifica host, puerto, dbname, usuario y contraseña en DEFAULT_DSN.")
        sys.exit(1)


def truncate_all(cur):
    """Vacía todas las tablas en orden seguro (respeta FKs)."""
    tables = [
        "ux_response_item", "ux_response", "ux_item", "ux_instrument",
        "telemetry_event", "game_participant", "game",
        "sector", "map", "episode",
        "player", '"user"',
        "telemetry_staging", "etl_error_log",
    ]
    for t in tables:
        cur.execute(f"TRUNCATE {t} RESTART IDENTITY CASCADE")
    print("[OK] Tablas vaciadas.")


# ── Paso 1: Sembrado de datos de referencia ───────────────────────────────────

def seed_reference_data(cur):
    print("[1/4] Sembrando datos de referencia ...")

    # users
    execute_values(cur,
        """INSERT INTO "public"."user" (user_id, username, email, consent_given, consent_date)
           VALUES %s ON CONFLICT DO NOTHING""",
        USERS,
    )

    # players
    execute_values(cur,
        """INSERT INTO player (player_id, user_id, nickname)
           VALUES %s ON CONFLICT DO NOTHING""",
        PLAYERS,
    )

    # episodes
    execute_values(cur,
        """INSERT INTO episode (episode_id, name, description)
           VALUES %s ON CONFLICT DO NOTHING""",
        EPISODES,
    )

    # maps
    execute_values(cur,
        """INSERT INTO map (map_id, episode_id, map_code, map_name)
           VALUES %s ON CONFLICT DO NOTHING""",
        MAPS,
    )

    # sectors
    execute_values(cur,
        """INSERT INTO sector (sector_id, map_id, sector_name)
           VALUES %s ON CONFLICT DO NOTHING""",
        SECTORS,
    )

    # Ajustar secuencias para que los SERIAL no colisionen con IDs insertados
    for seq, val in [
        ("user_user_id_seq",     8),
        ("player_player_id_seq", 8),
        ("episode_episode_id_seq", 3),
        ("map_map_id_seq",       9),
        ("sector_sector_id_seq", 54),
    ]:
        cur.execute(f"SELECT setval('{seq}', {val})")

    # ux_instrument + ux_items
    cur.execute(
        """INSERT INTO ux_instrument (instrument_id, name, description, version)
           VALUES (%s, %s, %s, %s) ON CONFLICT DO NOTHING""",
        UX_INSTRUMENT,
    )
    execute_values(cur,
        """INSERT INTO ux_item (item_id, instrument_id, question_text, response_type)
           VALUES %s ON CONFLICT DO NOTHING""",
        UX_ITEMS,
    )
    cur.execute("SELECT setval('ux_item_item_id_seq', 10)")
    cur.execute("SELECT setval('ux_instrument_instrument_id_seq', 1)")

    # Generar partidas (games) y participantes basados en las filas del TSV
    # Se hace después de la carga del staging para conocer los game_ids reales.
    print("    Datos de referencia insertados.")


# ── Paso 2: Carga del TSV a staging ──────────────────────────────────────────

def load_staging(cur, tsv_path: str) -> int:
    print(f"[2/4] Cargando '{tsv_path}' a telemetry_staging ...")
    with open(tsv_path, "r", encoding="utf-8") as f:
        # Saltar cabecera
        next(f)
        cur.copy_expert(
            """COPY telemetry_staging
               (game_id, player_id, sector_id, tic, ts,
                x, y, z, angle, momx, momy, health, armor, ammo)
               FROM STDIN WITH (FORMAT TEXT, DELIMITER E'\\t', NULL '')""",
            f,
        )
    cur.execute("SELECT COUNT(*) FROM telemetry_staging")
    n = cur.fetchone()[0]
    print(f"    {n} filas en staging.")
    return n


# ── Paso 3 & 4: Transformación staging → core + error log ────────────────────

def transform(cur):
    print("[3/4] Transformando staging → telemetry_event ...")

    # --- 3a. Derivar el conjunto de (game_id, player_id) presentes en staging ---
    cur.execute("""
        SELECT DISTINCT
            game_id::INT,
            player_id::INT
        FROM telemetry_staging
        WHERE game_id  ~ '^[0-9]+$'
          AND player_id ~ '^[0-9]+$'
        ORDER BY game_id::INT
    """)
    game_player_pairs = cur.fetchall()

    # --- 3b. Insertar filas en `game` (una por game_id único) ---
    cur.execute("""
        SELECT DISTINCT game_id::INT, player_id::INT,
               MIN(ts)::TIMESTAMP AS start_time,
               MAX(ts)::TIMESTAMP AS end_time
        FROM telemetry_staging
        WHERE game_id  ~ '^[0-9]+$'
          AND player_id ~ '^[0-9]+$'
          AND ts ~ '^[0-9]{4}-'
        GROUP BY game_id::INT, player_id::INT
    """)
    game_rows = cur.fetchall()

    # Para cada game_id único, insertar una sola fila en game
    seen_games = {}
    for gid, pid, start, end in game_rows:
        if gid not in seen_games:
            # map_id: derivar desde los sector_ids que aparecen en ese game
            cur.execute("""
                SELECT s.map_id
                FROM telemetry_staging st
                JOIN sector s ON s.sector_id = st.sector_id::INT
                WHERE st.game_id = %s::TEXT
                  AND st.sector_id ~ '^[0-9]+$'
                LIMIT 1
            """, (str(gid),))
            row = cur.fetchone()
            map_id = row[0] if row else 1
            difficulty = random.choice(DIFFICULTIES)
            cur.execute("""
                INSERT INTO game (game_id, map_id, player_id, start_time, end_time, difficulty)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT DO NOTHING
            """, (gid, map_id, pid, start, end, difficulty))
            seen_games[gid] = True

    # Ajustar secuencia de game
    if seen_games:
        cur.execute(f"SELECT setval('game_game_id_seq', {max(seen_games.keys())})")

    # --- 3c. Insertar game_participant ---
    for gid, pid in game_player_pairs:
        cur.execute("""
            INSERT INTO game_participant (game_id, player_id, role, score)
            VALUES (%s, %s, 'player', 0)
            ON CONFLICT DO NOTHING
        """, (gid, pid))

    print(f"    Partidas insertadas: {len(seen_games)}")

    # --- 3d. Insertar telemetry_event con validación fila a fila ---
    # Procesamos en lotes de 5 000 para no saturar memoria.
    BATCH = 5000
    offset = 0
    total_ok = 0
    total_err = 0

    while True:
        cur.execute("""
            SELECT raw_id, game_id, player_id, sector_id, tic,
                   ts, x, y, z, angle, momx, momy, health, armor, ammo
            FROM telemetry_staging
            ORDER BY raw_id
            LIMIT %s OFFSET %s
        """, (BATCH, offset))
        rows = cur.fetchall()
        if not rows:
            break

        good = []
        errors = []

        for raw_id, game_id, player_id, sector_id, tic, ts, x, y, z, \
                angle, momx, momy, health, armor, ammo in rows:
            reason = None
            try:
                g   = int(game_id)
                p   = int(player_id)
                sec = int(sector_id)          # sector_id NOT NULL
                t   = int(tic)
                ts_ = datetime.strptime(ts[:26], "%Y-%m-%d %H:%M:%S.%f")
                xv  = float(x)
                yv  = float(y)
                zv  = float(z)
                av  = float(angle)
                mx  = float(momx)
                my_ = float(momy)
                hv  = int(health) if health not in (None, "") else None
                arv = int(armor)  if armor  not in (None, "") else None
                amv = int(ammo)   if ammo   not in (None, "") else None

                if hv is not None and not (0 <= hv <= 200):
                    reason = f"health fuera de rango: {hv}"
                elif arv is not None and not (0 <= arv <= 200):
                    reason = f"armor fuera de rango: {arv}"

            except (ValueError, TypeError) as e:
                reason = str(e)

            if reason:
                errors.append((raw_id, reason))
                total_err += 1
            else:
                good.append((g, p, sec, t, ts_, xv, yv, zv, av, mx, my_, hv, arv, amv))
                total_ok += 1

        # Insertar filas válidas (ignorar duplicados por la UNIQUE constraint)
        if good:
            execute_values(cur, """
                INSERT INTO telemetry_event
                    (game_id, player_id, sector_id, tic, timestamp,
                     x, y, z, angle, momx, momy, health, armor, ammo)
                VALUES %s
                ON CONFLICT ON CONSTRAINT uq_telemetry_event DO NOTHING
            """, good)

        # Registrar errores
        if errors:
            execute_values(cur, """
                INSERT INTO etl_error_log (raw_id, error_msg)
                VALUES %s
            """, errors)

        offset += BATCH
        print(f"    Procesadas {offset} filas de staging ...", end="\r")

    print(f"\n    Filas insertadas en telemetry_event : {total_ok}")
    print(f"    Filas rechazadas en etl_error_log   : {total_err}")


# ── Paso opcional: sembrar respuestas UX sintéticas ──────────────────────────

def seed_ux_responses(cur):
    print("[4/4] Sembrando respuestas UX (BANGS) ...")
    cur.execute("SELECT game_id, player_id FROM game ORDER BY game_id LIMIT 40")
    games = cur.fetchall()

    responses = []
    items_per_response = []
    resp_id = 1

    for game_id, player_id in games:
        # El user_id coincide con player_id en este dataset
        responses.append((resp_id, player_id, 1, game_id))
        for item_id in range(1, 11):
            likert_val = str(random.randint(1, 7))
            items_per_response.append((resp_id, item_id, likert_val))
        resp_id += 1

    execute_values(cur, """
        INSERT INTO ux_response (response_id, user_id, instrument_id, game_id)
        VALUES %s ON CONFLICT DO NOTHING
    """, responses)

    execute_values(cur, """
        INSERT INTO ux_response_item (response_id, item_id, response_value)
        VALUES %s ON CONFLICT DO NOTHING
    """, items_per_response)

    print(f"    Respuestas UX insertadas: {len(responses)}")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="ETL: TSV → PostgreSQL")
    parser.add_argument("--tsv",      default="/home/estudiante/bases/entrega B/telemetry_raw.tsv", help="Ruta al TSV")
    parser.add_argument("--host",     default=DEFAULT_DSN["host"])
    parser.add_argument("--port",     default=DEFAULT_DSN["port"],     type=int)
    parser.add_argument("--dbname",   default=DEFAULT_DSN["dbname"])
    parser.add_argument("--user",     default=DEFAULT_DSN["user"])
    parser.add_argument("--password", default=DEFAULT_DSN["password"])
    parser.add_argument("--no-truncate", action="store_true",
                        help="No vaciar tablas antes de cargar")
    args = parser.parse_args()

    dsn = {
        "host": args.host, "port": args.port,
        "dbname": args.dbname, "user": args.user, "password": args.password,
    }

    conn = connect(dsn)
    cur  = conn.cursor()

    try:
        if not args.no_truncate:
            truncate_all(cur)

        seed_reference_data(cur)
        load_staging(cur, args.tsv)
        transform(cur)
        seed_ux_responses(cur)

        conn.commit()
        print("\n[✓] ETL completado exitosamente.")

    except Exception as e:
        conn.rollback()
        print(f"\n[ERROR] ETL abortado: {e}")
        raise
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()
