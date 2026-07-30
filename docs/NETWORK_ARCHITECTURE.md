# Multijugador con física del propietario

## Decisión para el prototipo

La sesión conserva un servidor dedicado de Godot 4 con ENet/UDP, pero cada
teléfono es propietario de la simulación física de su personaje. Esta decisión
prioriza controles inmediatos y resultados físicos divertidos durante la etapa
de prototipo. La autoridad física estricta y las medidas antitrampas quedan
fuera de alcance hasta que las reglas finales del juego estén definidas.

El servidor continúa siendo autoridad de:

- salas, capacidad, anfitrión y estado `ready`;
- identidad estable, token y ventana de reconexión;
- fase, tiempo, semilla y selección de minijuego;
- cantidad de rondas, eliminación, clasificación y puntuación acumulada;
- generación y retransmisión de eventos compartidos;
- pertenencia de cada estado al jugador que lo envía.

`RoomPhase` existe una sola vez en `shared/net_constants.gd`. La presentación
del cliente convierte explícitamente `WAITING`, `COUNTDOWN`, `ACTIVE` y
`RESULT`; nunca convierte sus números directamente a una enumeración visual.
Esto evita que `ACTIVE` pueda mostrarse como “ronda terminada”.

Cada cliente es propietario de:

- entrada, `CharacterBody3D` y colisiones completas de su personaje;
- salto, impulso, caída y respuesta a meteoritos/ondas/agua;
- vida y partes desprendidas resultantes de esas colisiones;
- cámara, animación, audio, efectos y calidad visual.

## Capas

```text
shared/
  net_constants.gd       tasas, canales, límites y flags
  net_codec.gd           estado propietario y snapshots empaquetados

server/
  dedicated_server.gd    ENet, RPC y retransmisión; sin recursos visuales
  room_manager.gd        hasta cinco salas dentro del proceso
  room_state.gd          fase, eventos y snapshots de una sala
  session_manager.gd     identidad, peer actual y reconexión
  session_state.gd       último estado aceptado del propietario

client/
  network_client.gd      ENet, RPC, envío local y señales para presentación
```

No existe un predictor o una segunda simulación de movimiento. El bootstrap
crea exclusivamente la rama de servidor con `--server`, o la rama de cliente
con `/root/Network` y las escenas visuales.

## Flujo frecuente

El propietario simula a la frecuencia física local y envía un
`PackedByteArray` de 22 bytes a 20 Hz mientras se mueve y 5 Hz cuando está
quieto. Los cambios de vida o máscara corporal se envían inmediatamente:

```text
sequence + position + velocity + yaw + health + body_mask
```

El servidor comprueba versión, orden, números finitos y límites amplios para
evitar estados corruptos. Después conserva el resultado sin recalcularlo. A 10
Hz genera para cada destinatario un snapshot de 24 bytes de cabecera más 24
bytes por jugador remoto. La cabecera incluye la confirmación del estado propio,
por lo que no devuelve su transformación redundante: 24 bytes si está solo, 48
con dos jugadores y 120 con cinco.

- canal 0 `reliable`: sesión, lobby, reconexión y fase;
- canal 1 `unreliable_ordered`: estados propietarios y snapshots;
- canal 2 `reliable`: meteoritos, ondas y empujes.

Los clientes remotos interpolan y extrapolan brevemente posición/velocidad. El
cliente propietario nunca aplica a su cuerpo el snapshot devuelto por el
servidor; sólo usa la secuencia como confirmación de relay. Así el RTT no puede
detener, arrastrar o hacer flotar al jugador local.

El HUD consulta directamente las estadísticas de `ENetPacketPeer` y muestra el
RTT medio. La pérdida sólo aparece cuando llega al 1 %, para no añadir ruido
visual en una conexión sana.

## Rondas, eliminación y clasificación

El anfitrión elige 3, 5 o 7 rondas antes de iniciar. Al llegar a cero de vida,
el propietario pasa a una cámara superior, deja de colisionar y replica vida
cero. El servidor bloquea cualquier intento posterior de volver a vida durante
esa ronda. El siguiente minijuego reutiliza el mismo jugador y restaura salud,
colisiones y partes.

Al terminar una ronda, el servidor ordena a los supervivientes por vida. Los
puestos reciben 5, 4, 3, 2 o 1 puntos; los empates de vida reciben los mismos
puntos y los eliminados reciben cero. Una RPC fiable publica nombres, vida,
puntos de ronda y total. Después de la cantidad elegida se conserva la
clasificación final y se anuncia al jugador con mayor puntuación.

La clasificación fiable incluye un `match_id` y número de ronda. El cliente usa
ambos para guardar una sola vez XP, partidas, rondas, supervivencias y
victorias. Jugar local no toca esos contadores. Durante esta fase el servidor
mantiene las cifras en memoria sólo para mostrarlas en la sala; la persistencia
real sigue en `user://profile.cfg`.

La clasificación final ofrece dos transiciones explícitas:

- **Volver a la sala** reutiliza el mismo `room_id`, limpia puntuación y
  estados `ready`, conserva jugadores y permite seleccionar de nuevo.
- **Salir** abandona la sala y regresa a la lista multijugador.

El servidor envía primero el estado completo de espera y después la señal de
reapertura por el mismo canal fiable. El autoload de red conserva ese estado
durante el cambio de escena para que el menú nunca aparezca vacío.

## Peligros y empujes

El servidor genera una sola descripción compacta de cada peligro. Todos los
clientes representan el mismo meteorito u onda, pero sólo el propietario
resuelve el contacto contra su personaje. El resultado local —incluidos impulso,
vida y máscara corporal— viaja en el siguiente estado y se replica a los demás.

Un empujón se solicita al servidor, que valida sala, distancia y dirección usando
los últimos estados conservados. El teléfono objetivo aplica el impulso y luego
replica el resultado como cualquier otra física.

Este modelo permite pequeñas diferencias físicas entre teléfonos. Es una
propiedad aceptada del prototipo, no un error que deba reconciliarse.

## Reconexión

El perfil local conserva `stable_id` y `reconnect_token`. Durante 60 segundos el
servidor mantiene el último estado propietario: posición, velocidad, vida,
orientación, puntuación y máscara corporal. Una reconexión válida recupera el
mismo `player_id` y ese estado.

El lobby admite cinco salas en un proceso y cinco jugadores por sala. Sólo el
anfitrión inicia, se requieren al menos dos personas y todas deben marcarse
listas. El anfitrión también fija la longitud de partida. No hay matchmaking
público, migración de proceso, P2P, cuentas ni persistencia de servidor.

## Límite futuro

Un minijuego competitivo podrá declarar más adelante reglas autoritativas
específicas —por ejemplo daño de armas o puntuación— sin reemplazar la física
propietaria de todos los modos. No se añadirá rollback, física determinista ni
lag compensation hasta que una regla real lo necesite.
