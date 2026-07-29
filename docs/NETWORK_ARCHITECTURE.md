# Multijugador autoritativo

## Auditoría de la implementación anterior

La primera versión ya usaba `ENetMultiplayerPeer`, UDP y RPC de alto nivel, pero
era un relay:

- `scripts/network/network_manager.gd` ejecutaba cliente y servidor;
- cada cliente enviaba posición y orientación, y el servidor las retransmitía;
- un teléfono elegido como `simulation_host` decidía rondas y peligros;
- jugadores, sesión y estado de ronda usaban `Dictionary`;
- una desconexión eliminaba inmediatamente la identidad;
- el arranque headless cargaba el mismo autoload que el cliente.

La presentación también estaba mezclada con autoridad: `game.gd` enviaba
snapshots de `GrayboxPlayer`, y `DisasterController` preguntaba si el cliente
era host antes de generar reglas.

## Límite nuevo

```text
shared/
  net_constants.gd       tasas, canales, límites y flags
  movement_rules.gd      integración matemática común
  net_codec.gd           PackedByteArray para input y snapshots

server/
  dedicated_server.gd    ENet y RPC; no carga escenas visuales
  room_manager.gd        varias salas dentro del proceso
  room_state.gd          estado autoritativo de una sala
  session_manager.gd     identidad, peer actual y reconexión
  scenes/dedicated_server.tscn

client/
  network_client.gd      ENet, RPC, inputs, ACK y señales compatibles
  client_prediction.gd   historial, predicción y reconciliación
```

El bootstrap crea exactamente una rama:

- `--server`: cambia a la escena dedicada y no crea `NetworkClient`;
- normal: crea `/root/Network` y luego carga `scenes/menu.tscn`; el menú decide
  entre juego local y lobby multijugador.

## Frecuencias y canales

- servidor lógico: 20 ticks/s;
- inputs: máximo 20 paquetes/s;
- snapshots: 10 paquetes/s en la primera etapa;
- canal 0 `reliable`: registro, aceptación, reconexión, jugadores y cambios de
  sesión;
- canal 1 `unreliable_ordered`: input y snapshots;
- canal 2 `reliable`: eventos críticos de juego que no pertenezcan a sesión.

Los mensajes frecuentes son `PackedByteArray`. Movimiento y ángulo están
cuantizados a enteros de 16 bits, y posición/velocidad tienen precisión de un
centímetro. Un input ocupa 12 bytes. El snapshot ocupa 20 bytes de cabecera más
24 por jugador conectado: 44 bytes para uno, 68 para dos y 140 para cinco. No
reserva ni transmite slots vacíos.
Metadatos infrecuentes pueden seguir usando parámetros RPC tipados, pero no
JSON.

## Estado mínimo

Cada sala conserva ID, fase, semilla y tiempos de ronda. Cada sesión conserva
una identidad estable, `peer_id` actual, token aleatorio, vencimiento de
reconexión, posición, velocidad, yaw, vida/actividad, puntuación, máscara
corporal y último input procesado.

No existen cámaras, luces, materiales, texturas, audio, partículas, HUD ni
animación en el árbol dedicado. Los límites autoritativos de la primera etapa
son matemáticos: caja exterior, alturas de suelo/plataforma/escalones y cuatro
pilares circulares. No se cargan `StaticBody3D` ni shapes. Esta aproximación
evita que el servidor atraviese las piezas principales del mapa y luego
arrastre al cliente hacia una posición contradictoria.

## Movimiento

El cliente envía secuencia, vector de movimiento, yaw y flags de acciones. El
servidor valida rango, orden y frecuencia, integra a 20 Hz y publica estado más
el último número de input procesado.

El cliente aplica de inmediato el mismo `MovementRules`, conserva inputs sin ACK
y, al recibir su estado:

1. fija la base autorizada;
2. elimina inputs confirmados;
3. reproduce los pendientes;
4. corrige suavemente el nodo visual.

Los remotos guardan dos snapshots y se interpolan. Su animación se deduce de la
velocidad recibida.

El render local usa una zona muerta amplia: errores pequeños no mueven al
personaje visible, discrepancias medias convergen lentamente y sólo un error
superior a varios metros provoca teletransporte. La autoridad lógica se
mantiene para snapshots, empujones, límites y resultados.

## Reconexión

El perfil local conserva `stable_id` y `reconnect_token`. Al volver antes de 60
segundos, el servidor asocia el nuevo `peer_id` con la sesión anterior y
continúa posición, vida y puntuación. Al vencer, la sala purga la sesión y
notifica su eliminación.

El lobby admite como máximo cinco salas dentro de un solo proceso y cada sala
reserva hasta cinco sesiones. El creador puede iniciar con un mínimo de dos
personas únicamente cuando todos confirmaron que están listos. La variante de
personaje forma parte del perfil lógico de sala y queda bloqueada al comenzar;
no se sincronizan meshes ni materiales. El proceso ENet admite 25 clientes
simultáneos, pero cada
`SessionManager` aplica por separado el límite de cinco. No hay matchmaking
público, migración de proceso, P2P, cuentas ni persistencia del lado servidor.
