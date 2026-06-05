# ============================================================
# Makefile – doom_telemetry
# Requiere: psql en el PATH (Git Bash / MSYS2 / PowerShell)
# Uso:  make <target>
# ============================================================

DB      = doom_telemetry
USER    = estudiante
HOST    = localhost
PORT    = 5432
PSQL    = psql -U $(USER) -h $(HOST) -p $(PORT) -d $(DB)

# Rutas a los scripts SQL (relativas a este Makefile)
DDL     = ddl_schema.sql
SEED    = poblar_tablas_ep,map,sec,usr\ plyr,gm,\ UX.sql
ETL     = importar_telemetry_data.sql

# ============================================================
# Targets
# ============================================================

.PHONY: all setup seed etl reset help

## Corre todo en orden: DDL → seed → ETL
all: setup seed etl

## 1. Crea todas las tablas e índices
setup:
	@echo "[1/3] Creando esquema..."
	$(PSQL) -f "$(DDL)"
	@echo "      Esquema creado OK."

## 2. Pobla tablas maestras (episode, map, user, player, game, UX)
seed:
	@echo "[2/3] Poblando tablas maestras..."
	$(PSQL) -f "$(SEED)"
	@echo "      Seed OK."

## 3. Importa telemetría desde los TSV
etl:
	@echo "[3/3] Importando telemetría (ETL)..."
	$(PSQL) -f "$(ETL)"
	@echo "      ETL OK."

## Borra y recrea la base de datos desde cero (¡destructivo!)
reset:
	@echo ">>> Borrando y recreando $(DB)..."
	psql -U $(USER) -h $(HOST) -p $(PORT) -d postgres -c "DROP DATABASE IF EXISTS $(DB);"
	psql -U $(USER) -h $(HOST) -p $(PORT) -d postgres -c "CREATE DATABASE $(DB) OWNER $(USER);"
	@echo "    Base de datos recreada. Corre 'make all' para repoblar."

## Muestra este menú
help:
	@echo ""
	@echo "  Targets disponibles:"
	@echo "    make all      -> setup + seed + etl  (flujo completo)"
	@echo "    make setup    -> solo DDL / tablas"
	@echo "    make seed     -> solo datos maestros"
	@echo "    make etl      -> solo importar TSV"
	@echo "    make reset    -> DROP + CREATE database (destructivo)"
	@echo ""
