# DOOM Chocolate Telemetry Database

Repositorio del proyecto de bases de datos enfocado en el diseño e implementación de un sistema para el almacenamiento y análisis de telemetría y experiencia de usuario (UX) del videojuego DOOM utilizando Chocolate Doom y PostgreSQL.

---

# Integrantes

- Alejandro Méndez
- Nicolás Espinza
- Juan José Castillo
- Laura Rueda

---

# Descripción del Proyecto

Este proyecto tiene como objetivo diseñar una base de datos relacional capaz de almacenar información generada durante partidas de DOOM ejecutadas mediante Chocolate Doom.

El sistema permite registrar:

- Usuarios y jugadores
- Partidas y participantes
- Eventos de telemetría del juego
- Episodios, mapas y sectores
- Instrumentos de evaluación UX
- Respuestas y métricas de experiencia de usuario

La información recolectada será utilizada para análisis posteriores relacionados con comportamiento del jugador, patrones de movimiento y experiencia de juego.

---

# Objetivos

## Objetivo General

Diseñar e implementar una base de datos relacional para almacenar y analizar telemetría y datos UX generados durante partidas de DOOM.

## Objetivos Específicos

- Modelar las entidades y relaciones principales del dominio del videojuego.
- Diseñar un esquema relacional normalizado que garantice integridad y consistencia de los datos.
- Facilitar el análisis de telemetría y experiencia de usuario mediante consultas SQL.

---

# Telemetría

La telemetría obtenida desde Chocolate Doom incluye variables relacionadas con el estado y movimiento del jugador, tales como:

- Coordenadas espaciales (`x`, `y`, `z`)
- Ángulo de orientación
- Momentum (`momx`, `momy`)
- Tics del motor del juego
- Timestamps de eventos

---

# Licencia

Proyecto académico desarrollado con fines educativos y de investigación.
