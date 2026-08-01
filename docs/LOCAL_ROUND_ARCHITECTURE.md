# Contrato local de mapa y ronda

Aquí “ronda” nombra únicamente el ciclo técnico interno de un minijuego
(`prepare → active → result → cleanup`). No existe una configuración de varias
rondas ni una rotación automática: al terminar un minijuego se vuelve a la
sala.

Esta capa funciona sin `Network` y no modifica la arquitectura ENet existente.
Su objetivo es que mapas, eventos y partidas puedan aprobarse en un cliente antes
de decidir qué resultados necesitarán autoridad remota.

## Responsabilidades

- `MinigameMapDefinition`: datos inmutables del contenido; no ejecuta física.
- `LocalMapHost`: monta una construcción para la semilla y la elimina completa.
- `LocalEventHost`: no se monta en la escena oficial de fútbol; queda reservado
  para un futuro módulo de desastres.
- `LocalFootballHost`: cuenta goles, restablece el balón y termina la práctica;
  no crea geometría ni reemplaza la física nativa del balón.
- `LocalRoundController`: único dueño de fases, tiempos, bloqueo de controles y
  limpieza.
- `LocalBaseCharacter`: movimiento e impulsos inmediatos; desconoce mapas,
  partidas y red.
- `LocalShooterHost`: arma seleccionada por semilla, hitscan, bots locales,
  vida, cargadores independientes, respawn y clasificación individual; no
  crea el escenario.

El mapa declara:

- `footprint` y `playable_area_index`;
- puntos de aparición, zonas seguras, eventos y navegación;
- objetos disponibles;
- desastres y minijuegos compatibles;
- nombres de slots modulares.

La semilla sigue formando parte del contrato aunque el primer campo sea
determinista. `campo_futbol_local` es el primer paquete de minijuego completo:
escena propia, ocho puntos de aparición, cancha, dos porterías, paredes de
rebote y balón
`RigidBody3D`. `LocalMapHost` instancia `map_scene` y sólo conserva el
constructor anterior como fallback para definiciones sin escena. No existe
generación procedural ambiciosa.

Los modos por equipos consultan la misma `MinigameMapDefinition` para equipo,
spawn y orientación inicial o de reaparición. En modos individuales, cada
spawn mira automáticamente al centro geométrico del conjunto. Bateball ofrece ocho posiciones
únicas (4v4); su escena de arena no duplica ese roster y únicamente aporta la
geometría y el `AABB` válido para el balón.

## Ciclo y limpieza

```text
PREPARE → RULES → COUNTDOWN → ACTIVE → RESULT → CLEANUP → IDLE
```

`stop_and_clean()` incrementa una generación interna. Todo temporizador viejo
comprueba esa generación al despertar, por lo que una partida cancelada no puede
continuar ni reactivar contenido. La prueba marca tres goles en ocho ejecuciones y
ejecuta una cancelación; todas vuelven exactamente al mismo conteo de nodos y
restauran la cámara en tercera persona.

## Autoridad futura

- mapa, semilla, fase, daño decisivo y resultado: autoridad de sesión;
- movimiento propietario: predicción local y corrección sólo cuando haga falta;
- animación, audio, partículas y fragmentos: cada cliente;
- gol y resultado compartido: autoridad futura;
- balón visual, animaciones, audio y mira: local.

Esta clasificación documenta el destino futuro, pero el partido actual sigue
siendo completamente local hasta su aprobación en el POCO.

La zona de evento no implica una pared. En la isla de referencia, la costa es
el límite físico y el rectángulo 30/60/100 sólo dimensiona apariciones y reglas.
Fútbol usa vallas visibles propias y no superpone una segunda pared invisible.
Otro modo cerrado todavía puede optar explícitamente por `PHYSICAL_AREA`.

Los desastres permanecen fuera de este primer minijuego. Un tsunami futuro
deberá nacer fuera de la costa, atravesar la isla y consultar la huella del
mapa sin acoplarse al controlador de fútbol.
