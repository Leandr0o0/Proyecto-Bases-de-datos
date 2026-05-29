# Entregable B — Base de datos de Telemetría y UX para Chocolate-Doom
**Proyecto Bases de Datos · Javeriana 2026**

---

## ¿De qué trata esto?

Este entregable corresponde a la implementación de la base de datos diseñada en la Entrega A. La idea es tomar los datos que emite el juego Chocolate-Doom mientras alguien juega — cosas como la posición del jugador, hacia dónde mira, su salud, etc. — y guardarlos de forma organizada en PostgreSQL para poder analizarlos después.

Además de la telemetría del juego, también se guardan las respuestas de los jugadores a una encuesta de experiencia de usuario (instrumento PENS), y datos básicos de cada sesión de juego.

---

## ¿Qué hay en este entregable?

```
Entregable B/
├── 01_DDL.sql           → Crea toda la estructura de la base de datos (tablas, índices, etc.)
├── staging.sql          → Define cómo se reciben y validan los datos crudos del juego
├── importar_tsv.sql     → Guía para cargar el archivo de telemetría desde pgAdmin
├── 02_etl_load.py       → Script Python que hace todo el proceso de carga automáticamente
├── 04_games_and_ux.sql  → Inserta los datos de partidas, jugadores y encuestas UX
├── generate_data .py    → El script que generó los datos sintéticos de telemetría
└── telemetry_raw.tsv    → El archivo con ~140.000 filas de telemetría del juego
```

---

## ¿Qué se implementó?

### La base de datos
Se crearon las tablas necesarias para guardar toda la información del dominio: los usuarios que participaron en el estudio, sus identidades dentro del juego, los episodios y mapas que jugaron, y cada evento de telemetría registrado por el motor del juego. También se crearon tablas para el instrumento de encuesta UX y las respuestas de cada jugador.

### El proceso de carga (ETL)
Cuando el juego emite datos, los guarda en un archivo TSV (básicamente una tabla de texto). Para cargar eso a la base de datos de forma segura, se creó un proceso de tres pasos: primero se carga todo tal cual a una tabla provisional, luego se validan los datos (que los números sean números, que no haya duplicados, etc.), y finalmente los datos válidos pasan a las tablas definitivas. Los datos que tengan algún error quedan registrados en un log separado.

### Los datos sintéticos
Como no se tenían sesiones reales de miles de jugadores, se generaron datos sintéticos con un script Python que simula movimientos realistas dentro del juego. En total se generaron:

- 3 episodios del juego (Knee-Deep in the Dead, The Shores of Hell, Inferno)
- 9 mapas en total (3 por episodio)
- 8 jugadores distintos
- 24 partidas (cada jugador jugó 3 partidas en mapas diferentes)
- ~140.000 filas de telemetría — muy por encima del mínimo de 20.000 requerido

### La encuesta UX
Se usó el instrumento **PENS (Player Experience of Need Satisfaction)**, que mide qué tan satisfechas quedan las necesidades psicológicas del jugador al jugar. Tiene 21 preguntas en escala del 1 al 7, agrupadas en tres dimensiones: competencia, autonomía y relación con otros jugadores. Se insertó una respuesta completa por cada partida registrada.

---

## Cómo correr todo

> Asegúrate de tener PostgreSQL instalado y corriendo, y Python con la librería `psycopg2-binary`.
> ```bash
> pip install psycopg2-binary
> ```

### Paso 1 — Crear la base de datos

Desde pgAdmin o desde la terminal:

```sql
CREATE DATABASE doom_v2;
```

---

### Paso 2 — Crear las tablas

```bash
psql -U postgres -d doom_v2 -f 01_DDL.sql
```

Esto crea todas las tablas, las restricciones de integridad, los índices y las tablas auxiliares del ETL.

---

### Paso 3 — Insertar los datos de partidas y encuestas UX

```bash
psql -U postgres -d doom_v2 -f 04_games_and_ux.sql
```

Esto carga episodios, mapas, sectores, usuarios, jugadores, partidas, el instrumento PENS con sus 21 preguntas y las respuestas UX de cada jugador.

---

### Paso 4 — Cargar la telemetría

Ejecuta el script Python apuntando al archivo TSV:

```bash
python 02_etl_load.py \
    --tsv telemetry_raw.tsv \
    --host localhost \
    --port 5432 \
    --dbname doom_v2 \
    --user postgres \
    --password postgres
```

El script se encarga de cargar el staging, validar los datos y pasarlos a la tabla definitiva. Al terminar imprime cuántas filas se insertaron correctamente y cuántas tuvieron algún error.

---

### Verificación rápida

Una vez completados los pasos anteriores, puedes correr estas consultas para confirmar que todo quedó bien:

```sql
SELECT COUNT(*) FROM telemetry_event;    -- debe dar ~140.000
SELECT COUNT(*) FROM game;               -- debe dar 24
SELECT COUNT(*) FROM player;             -- debe dar 8
SELECT COUNT(*) FROM ux_response;        -- debe dar 24
SELECT * FROM v_etl_summary;             -- resumen del proceso de carga
```
