# Contrato local de mapa y ronda

Esta capa funciona sin `Network` y no modifica la arquitectura ENet existente.
Su objetivo es que mapas, eventos y rondas puedan aprobarse en un cliente antes
de decidir qué resultados necesitarán autoridad remota.

## Responsabilidades

- `MinigameMapDefinition`: datos inmutables del contenido; no ejecuta física.
- `LocalMapHost`: monta una construcción para la semilla y la elimina completa.
- `LocalEventHost`: conserva el evento físico de referencia anterior, aislado
  y disponible para futuros modos de desastre.
- `LocalFootballHost`: cuenta goles, restablece el balón y termina la práctica;
  no crea geometría ni reemplaza la física nativa del balón.
- `LocalRoundController`: único dueño de fases, tiempos, bloqueo de controles y
  limpieza.
- `LocalBaseCharacter`: movimiento e impulsos inmediatos; desconoce mapas,
  rondas y red.

El mapa declara:

- `footprint` y `playable_area_index`;
- puntos de aparición, zonas seguras, eventos y navegación;
- objetos disponibles;
- desastres y minijuegos compatibles;
- nombres de slots modulares.

La semilla sigue formando parte del contrato aunque el primer campo sea
determinista. `campo_futbol_local` es el primer paquete de minijuego completo:
escena propia, cinco puntos de aparición, cancha cerrada, portería y balón
`RigidBody3D`. `LocalMapHost` instancia `map_scene` y sólo conserva el
constructor anterior como fallback para definiciones sin escena. No existe
generación procedural ambiciosa.

## Ciclo y limpieza

```text
PREPARE → RULES → COUNTDOWN → ACTIVE → RESULT → CLEANUP → IDLE
```

`stop_and_clean()` incrementa una generación interna. Todo temporizador viejo
comprueba esa generación al despertar, por lo que una ronda cancelada no puede
continuar ni reactivar contenido. La prueba marca tres goles en ocho rondas y
ejecuta una cancelación; todas vuelven exactamente al mismo conteo de nodos y
restauran la cámara en tercera persona.

## Autoridad futura

- mapa, semilla, fase, daño decisivo y resultado: autoridad de sesión;
- movimiento propietario: predicción local y corrección sólo cuando haga falta;
- animación, audio, partículas y fragmentos: cada cliente;
- gol y resultado compartido: autoridad futura;
- balón visual, animaciones, audio y mira: local.

Esta clasificación documenta el destino futuro, pero el laboratorio sigue
siendo completamente local hasta su aprobación en el POCO.

La zona de evento no implica una pared. En la isla de referencia, la costa es
el límite físico y el rectángulo 30/60/100 sólo dimensiona apariciones y reglas.
Fútbol usa vallas visibles propias y no superpone una segunda pared invisible.
Otro modo cerrado todavía puede optar explícitamente por `PHYSICAL_AREA`.

Los desastres permanecen fuera de este primer minijuego. Un tsunami futuro
deberá nacer fuera de la costa, atravesar la isla y consultar la huella del
mapa sin acoplarse al controlador de fútbol.
