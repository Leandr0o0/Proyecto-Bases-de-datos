# ETL — Doom Telemetry DB
## Guía de ejecución paso a paso (pgAdmin)

### Archivos en este directorio

| Archivo | Propósito |
|---|---|
| `poblar_tablas_ep,map,sec,usr plyr,gm, UX.sql` | Pobla episode, map, user, player, game, BANGS (ux_instrument/ux_item), y respuestas UX |
| `importar_telemetry_data.sql` | Pipeline completo: staging → sector → telemetry_event |

---

### Orden de ejecución

#### 1. Ejecutar el DDL (si no está hecho)
Abrir `ddl_schema.sql` en pgAdmin Query Tool y ejecutar completo.

#### 2. Ejecutar `poblar_tablas_ep,map,sec,usr plyr,gm, UX.sql`
Abre el archivo en Query Tool y ejecuta. Esto crea:
- 3 episodios, 3 mapas
- 6 usuarios + 6 players
- 18 games (3 por jugador × 6 jugadores)
- Instrumento BANGS con 18 ítems
- 6 respuestas UX (una por jugador, con 18 ítems cada una)

#### 3. Ejecutar el bloque ALTER de `importar_telemetry_data.sql` (solo una vez)
Copia y ejecuta únicamente este bloque (al inicio del archivo):
```sql
ALTER TABLE staging_telemetry
  ADD COLUMN IF NOT EXISTS map_id_raw   TEXT,
  ...
```

#### 4. Cargar cada TSV via pgAdmin Import/Export

Para **cada archivo** (alejandro.tsv, nicolas.tsv, etc.):

1. En el panel izquierdo, click derecho sobre `staging_telemetry`
2. Seleccionar **Import/Export Data...**
3. Configurar:
   - **Import** (no Export)
   - **Format:** text
   - **Delimiter:** `Tab` (o `\t`)
   - **Header:** OFF (los TSV no tienen encabezado)
4. En la pestaña **Columns**, seleccionar exactamente estas columnas en orden:
   ```
   map_id_raw, ts_raw, tic_raw, x_raw, y_raw, z_raw,
   angle_raw, momx_raw, momy_raw, health_raw, armor_raw,
   ammo_raw, sector_grid_raw
   ```
5. Hacer clic en OK.

#### 5. Asignar game_id en staging

Después de importar cada TSV, ejecutar `assign_game_id` con el player_id correspondiente:

```sql
-- Tras importar alejandro.tsv:
SELECT assign_game_id(1);

-- Tras importar nicolas.tsv:
SELECT assign_game_id(2);

-- Tras importar juanjose.tsv:
SELECT assign_game_id(3);

-- Tras importar laura.tsv:
SELECT assign_game_id(4);

-- Tras importar sebastian.tsv:
SELECT assign_game_id(5);

-- Tras importar cristian.tsv:
SELECT assign_game_id(6);
```

#### 6. Ejecutar el pipeline de validación y carga

Ejecutar el resto de `importar_telemetry_data.sql` desde el PASO 1 hasta el final.

Al finalizar deberías ver algo así:

```
fuente            | filas
------------------+-------
staging           | 21600
telemetry_event   | 21600
errores_etl       |     0
```

---

### Tabla de referencia: game_id por jugador y mapa

| Jugador    | player_id | map1 (E1M1) | map2 (E2M1) | map3 (E3M1) |
|------------|-----------|-------------|-------------|-------------|
| alejandro  | 1         | 1           | 2           | 3           |
| nicolas    | 2         | 4           | 5           | 6           |
| juanjose   | 3         | 7           | 8           | 9           |
| laura      | 4         | 10          | 11          | 12          |
| sebastian  | 5         | 13          | 14          | 15          |
| cristian   | 6         | 16          | 17          | 18          |

---

### Solución de problemas comunes

**Error: `sector_id` duplicado en tabla `sector`**
→ Normal si ya corriste el pipeline antes. El `ON CONFLICT DO NOTHING` lo maneja.

**Error: `UNIQUE constraint (game_id, tic)` en telemetry_event**
→ Significa que estás re-cargando datos ya insertados. Ejecuta primero:
```sql
TRUNCATE telemetry_event;
TRUNCATE staging_telemetry;
```

**Error: `game_id IS NULL` en staging**
→ No ejecutaste `assign_game_id()` para ese jugador. El PASO 1 de validación marcará esas filas como inválidas y las registrará en `etl_error_log`.

**Los timestamps de los TSV se superponen entre jugadores**
→ Esperado — todos jugaron "al mismo tiempo" en sesiones independientes. Cada game tiene su propio `game_id`, así que no hay conflicto.
