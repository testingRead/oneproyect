# Auditoría de la base local y LAN

Estado revisado: 31 de julio de 2026, rama `feature/local-minigame`.

La auditoría se mantiene como documento vivo: los hallazgos ya corregidos se
marcan como tales para no volver a introducir la implementación anterior.

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
- Corregido: orientación visual y orientación de cámara son operaciones
  separadas y cada spawn configura ambas hacia el centro.
- Corregido: la mira superior transforma el arrastre usando el yaw de cámara
  del equipo.

### Ronda

- Corregido localmente: existe un reloj continuo de fase y la cuenta regresiva
  emite y muestra `3, 2, 1`; antes el HUD escribía un `3` literal.
- Los clientes LAN todavía derivan PREPARE, RULES, COUNTDOWN, ACTIVE y RESULT
  desde la misma semilla y el mismo inicio. La fase LAN autoritativa completa
  sigue siendo una tarea de consolidación.
- Los eventos de juego ya incluyen ronda y revisión, y el receptor descarta
  rondas distintas y revisiones antiguas.

### Corona

- Corregido: sólo el anfitrión decide el portador y lo replica por `peer_id`
  mediante el contrato versionado de ronda.
- Corregido: un enfriamiento de 0,65 s evita intercambios repetidos mientras
  dos cápsulas permanecen solapadas.
- Corregido: si nadie toma la corona el resultado es empate, no derrota.

### Bomba

- Corregido: el anfitrión elige un portador inicial determinista por semilla,
  decide contactos y ejecuta la única mecha capaz de terminar la ronda.
- Corregido: portador, tiempo restante, explosión y perdedor viajan como
  eventos fiables identificados por ronda.
- Corregido: sólo pierde quien tenía la bomba; los demás sobreviven.

### Tornado

- Corregido: el anfitrión avanza trayectoria, reloj, objetos y daño; publica
  el peligro a 15 Hz por un canal `unreliable_ordered`.
- La respuesta de movimiento del propietario continúa local para no añadir
  latencia, mientras la vida confirmada usa eventos fiables.
- Corregido: el tornado daña a todos los participantes y no termina la ronda
  solamente porque haya muerto el anfitrión.

### Fútbol de rebote

- Corregido: sólo el anfitrión ejecuta goles, arqueros bot, reinicios y
  marcador; los demás aplican marcador y resultado oficiales.
- La patada responde inmediatamente en el cliente propietario y el anfitrión
  recibe la solicitud equivalente para producir el balón oficial; no son dos
  impulsos sobre el mismo cuerpo físico.
- Marcador y ganador de penales tienen estado LAN oficial. La elección del
  tirador en penales continúa limitada al anfitrión.

### Interfaz y cámara

- Corregido: fútbol usa primera persona, Bateball cámara elevada y corona,
  bomba y tornado usan tercera persona. Antes todo excepto Bateball se forzaba
  a primera persona.
- Corregido: mira y botón PATEAR sólo aparecen en fútbol y durante las fases
  donde corresponden; joystick, cámara táctil y salto se desactivan antes del
  inicio y después del final.
- Corregido: los marcadores de equipo dicen `TU EQUIPO`, no `TÚ`.
- Corregido: cada resultado explica la regla real del modo; Corona ya no
  mostrará accidentalmente el marcador de fútbol durante RESULT.

## Matriz semántica de minijuegos

| Modo | Cámara | Acción distintiva | Condición final | Autoridad LAN |
| --- | --- | --- | --- | --- |
| Fútbol de rebote | primera persona | patada orientada por cuerpo | 3 goles, tiempo y penales si empata | host: balón, goles, bots y marcador |
| Corona central | tercera persona | robar por contacto | portador al terminar; empate si nadie | host: portador con enfriamiento |
| Bomba de relevo | tercera persona | entregar por contacto | explota el portador al agotar la mecha | host: portador, mecha y explosión |
| Tornado | tercera persona | evitar embudo y proyectiles | tiempo o todos eliminados | host: peligro y daño; reacción local |
| Bateball | elevada oblicua | apuntar tiro / bate cargado | primer equipo a 2 | host: posesión, balón y marcador |

## Deuda identificada que no debe ocultarse

- Bateball ya usa el contrato versionado común para posesión y marcador. Los
  métodos RPC antiguos permanecen aislados hasta retirar sus pruebas legadas,
  pero la ruta activa no depende de ellos.
- Patada y bate ya usan un evento de acción no fiable y ordenado para que la
  animación remota acompañe el resultado físico sin bloquear el movimiento.
- Bateball confirma daño desde el host y respawnea al jugador eliminado en su
  spawn después de dos segundos. Todavía falta una animación visual específica
  de eliminación/reaparición.
- En penales LAN el anfitrión realiza la selección. Para una versión final por
  equipos deberá declararse explícitamente qué jugador patea cada turno.
- Los equipos se derivan de slots alternados, pero el roster debe congelarse
  al iniciar la ronda para que una desconexión no reasigne bandos.

### Presentación remota

- La locomoción remota ya usa la velocidad recibida.
- Eventos de animación discretos todavía no tienen un canal general; sólo el
  bate posee un RPC propio.
- Tornado aplica vida confirmada por evento. La salud genérica recibida dentro
  del snapshot de locomoción todavía no alimenta una barra visual remota.

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

Existe un único contrato de estado de ronda LAN para los modos consolidados,
en lugar de un RPC improvisado para cada texto del HUD.

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
