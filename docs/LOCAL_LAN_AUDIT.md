# Auditoría de la base local y LAN

Estado revisado: 31 de julio de 2026, rama `feature/local-minigame`.

## Alcance activo

La aplicación contiene actualmente dos rutas distintas:

1. `client/`, `server/`, `scripts/game.gd` y `scripts/player.gd`: multijugador
   dedicado anterior.
2. `scripts/local/`, `scripts/network/lan_session.gd` y
   `scenes/local/local_lab.tscn`: base local/LAN en desarrollo.

Los minijuegos que se prueban desde el menú Local/LAN utilizan la segunda
ruta. Durante esta consolidación no se eliminará ni rediseñará la primera,
pero tampoco se reutilizará accidentalmente como autoridad de la partida LAN.

## Flujo actual

```text
Menu
  -> OneProjectLanSession (sala, perfiles, listo, semilla)
  -> LocalDevelopmentLab
       -> LocalRoundController (fases y montaje)
       -> LocalMapHost (mapa y spawns)
       -> LocalBaseCharacter (entrada, cámara, física y animación)
       -> host específico del minijuego
       -> OneProjectLanSession (estado de jugadores y algunos eventos)
```

El host LAN retransmite posiciones de jugadores a 20 Hz y cuerpos rígidos a
15 Hz. Cada propietario mantiene movimiento y respuesta táctil local. Este
principio se conserva.

## Hallazgos confirmados

### Equipos y orientación

- Los slots ya se alternan `home, away, home, away`, pero la asignación no se
  congela como parte de un estado de ronda.
- `set_facing_direction()` gira sólo `VisualRoot`.
- Movimiento, primera persona e interacción usan el yaw de `CameraPivot`.
- El jugador `away` aparece en la mitad correcta y su modelo mira al centro,
  pero la cámara continúa mirando hacia `-Z`, es decir, hacia su propia
  portería.
- La mira superior transforma el arrastre directamente a ejes del mundo y no
  toma en cuenta el yaw del equipo.

### Ronda

- Cada cliente ejecuta sus propios temporizadores PREPARE, RULES, COUNTDOWN,
  ACTIVE y RESULT.
- La misma semilla reduce diferencias, pero no existe una revisión de ronda ni
  una fase autoritativa que permita rechazar eventos atrasados.
- Un RPC de una ronda anterior podría aplicarse sobre una ronda nueva.

### Corona

- Cada cliente conecta su propia `Area3D.body_entered`.
- Cada cliente detecta por distancia quién roba la corona.
- No existe ningún mensaje LAN para portador, revisión o resultado.
- Por eso dos teléfonos pueden mostrar portadores distintos indefinidamente.

### Bomba

- `start_match()` entrega la bomba al `player` local de cada teléfono.
- Cada cliente ejecuta su propia mecha y decide los contactos.
- Portador, tiempo de explosión y perdedor no se sincronizan.

### Tornado

- Cada cliente avanza `_path_time`, mueve el tornado y calcula impactos.
- Los cuerpos rígidos reciben snapshots del host, pero el tornado no forma
  parte de esos snapshots porque no es `RigidBody3D`.
- Vida, captura, tiempo y final pueden diferir entre teléfonos.

### Fútbol de rebote

- El balón recibe snapshots del host, pero todos los clientes ejecutan goles,
  arqueros bot, reinicios y marcador.
- Patadas de un cliente se aplican primero localmente y después otra vez en el
  host como solicitud de impulso.
- Marcador, bloqueo de gol y penales no tienen estado LAN oficial.

### Bateball

- Ya existe autoridad del host para portador y marcador.
- Sus RPC son específicos y constituyen una solución aislada que no cubre los
  demás minijuegos.
- Falta identificar cada actualización por ronda y revisión.

### Presentación remota

- La locomoción remota ya usa la velocidad recibida.
- Eventos de animación discretos todavía no tienen un canal general; sólo el
  bate posee un RPC propio.
- Salud recibida se almacena en `_lan_targets`, pero no se aplica a la
  presentación remota.

## Responsabilidad objetivo

| Sistema | Propietario | Host LAN | Otros clientes |
| --- | --- | --- | --- |
| Entrada y movimiento inmediato | simula | retransmite | interpola |
| Cámara y HUD | simula | no procesa | no procesa |
| Equipo y spawn | aplica | asigna una vez | aplica estado |
| Corona/bomba/posesión | predice sólo efecto visual | decide | aplica evento |
| Balón y objetos relevantes | respuesta local | estado físico oficial | interpola |
| Gol, daño y resultado | efecto inmediato opcional | decide | aplica evento |
| Partículas, sonido y animación | reproduce | envía evento mínimo | reproduce |
| Fase y reloj | muestra reloj local | inicia y corrige | deriva del estado |

## Diseño de sincronización

Se añadirá un único contrato de estado de ronda LAN, no un RPC independiente
improvisado para cada texto del HUD.

Cada evento llevará:

```text
round_id + revision + event_kind + actor_peer_id
+ integer_values + vector_values
```

Eventos fiables y poco frecuentes:

- fase de ronda;
- asignación de equipos y spawns;
- cambio de portador de corona, bomba o balón;
- gol, marcador, daño confirmado y resultado;
- explosión o final de evento.

Snapshots no fiables:

- posiciones y velocidades de jugadores;
- cuerpos rígidos relevantes;
- posición de un peligro móvil autoritativo.

Cada receptor ignorará una revisión antigua o un `round_id` que no coincida.

## Plan de corrección

### Etapa 1 — orientación y contrato común

1. Separar `set_facing_direction` de `set_view_direction`.
2. Alinear cámara, movimiento e interacción con el lado del equipo.
3. Transformar la mira superior desde espacio de pantalla a espacio del mundo.
4. Crear eventos LAN versionados por ronda.

### Etapa 2 — portadores

1. Host único para corona.
2. Reutilizar el mismo contrato para bomba y Bateball.
3. Los clientes aplican portador por `peer_id`, nunca por nombre.
4. Añadir estado inicial y reenvío tardío para evitar eventos perdidos al
   cargar la escena.

### Etapa 3 — resultados y relojes

1. Host único para goles y marcador de ambos modos de balón.
2. Host único para mecha, explosión y perdedor de bomba.
3. Host único para fase, final y ganador.

### Etapa 4 — peligros y física

1. Tornado y objetos relevantes simulados por el host.
2. Cada cliente conserva efectos, sonido y reacción visual inmediata.
3. Evitar aplicar dos veces el mismo impulso local/remoto.

### Etapa 5 — validación

1. Pruebas unitarias de ejes y equipos para slots 0–7.
2. Dos procesos Godot: cambio de portador repetido y marcador.
3. Simulación con latencia, pérdida y reordenamiento de eventos.
4. Dos teléfonos reales antes de declarar estable cada minijuego.

## Criterio de cierre

Un minijuego LAN sólo se considera corregido cuando ambos teléfonos muestran
el mismo `round_id`, fase, portador, marcador, tiempo y resultado, mientras el
movimiento local continúa respondiendo sin esperar a la red.
