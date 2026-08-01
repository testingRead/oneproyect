# Base local consolidada

Fecha de consolidación: 2026-08-01.

Este documento fija la frontera de la base interna antes de una iteración de
interfaz. No es una promesa de lanzamiento público: describe qué rutas son
oficiales, qué integración se conserva y qué no debe tocarse sin una prueba.

## Ruta oficial de juego

```text
Bootstrap
├── Menú
│   ├── Sala local ─┐
│   └── Sala LAN ───┼── LocalDevelopmentLab
│                  │   ├── isla física y costa
│                  │   ├── LocalBaseCharacter
│                  │   ├── LocalMapHost
│                  │   ├── LocalRoundController
│                  │   └── hosts de minijuego
│                  └── vuelve a la misma sala
└── --local-development ── LocalDevelopmentLab directo
```

La isla es el mundo físico común. Cada `MinigameDefinition` monta sólo su
escena, objetos y límites de ronda; al terminar, `LocalRoundController` limpia
el contenido y devuelve al jugador a la sala.

## Sistemas aprobados

- Controlador local, colisión, cámara, salto y animación procedural.
- Joystick izquierdo y gesto derecho; en los modos de puntería se puede mover
  mientras se apunta y se suelta para ejecutar la acción.
- Física nativa de objetos rígidos: pelota, impactos, muros y rebotes.
- Ciclo preparar → reglas → cuenta atrás → activo → resultado → limpieza.
- Fútbol de rebote, corona, bomba, tornado, Bateball, balón de eliminación y
  arena de tiro.
- Sala LAN ENet con equipos por slots alternados, estado de objetos y eventos
  de ronda confiables.
- Marcador temporal de sala: empieza en cero, concede 3 puntos por victoria o
  1 por empate y se borra al cerrar/abandonar la sala.

## Integración remota preservada

`scenes/main.tscn`, `scripts/game.gd`, `scripts/minigames/` y sus mapas no son
la ruta Local/LAN actual. Se conservan porque aún sostienen el flujo de sala
remota, el servidor dedicado y sus pruebas de integración. No deben recibir
mecánicas nuevas durante el rediseño de UX; la migración futura deberá reutilizar
la base local y retirar esa ruta mediante una tarea explícita.

## Diagnóstico conservado

Las pruebas bajo `tests/` no se exportan al APK. Algunas son de captura,
capacidad, red o movimiento real y no se ejecutan en cada build, pero permanecen
como herramientas de diagnóstico. La validación normal cubre personajes, rondas
locales, minijuegos, sala LAN, códecs, servidor y menú.

## Retirado en esta consolidación

- `data/maps/isla_laboratorio.tres`: definición antigua sin cargas, referencias
  ni papel en la isla física actual.

No se eliminó ninguna escena, script, mapa o personaje que participe en una
ruta de menú, exportación o prueba activa.
