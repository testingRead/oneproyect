# Servidor dedicado

El servidor usa `ENetMultiplayerPeer` sobre UDP y la API multijugador de alto
nivel de Godot. Ejecuta `server/scenes/dedicated_server.tscn`, cuyo árbol sólo
contiene:

```text
Network (DedicatedServer)
└── RoomManager
    ├── Room1
    │   └── SessionManager
    └── … hasta Room5
```

No carga arena, jugador visual, cámara, luces, materiales, texturas, audio,
partículas, animaciones ni HUD. El preset `Linux Dedicated Server` incluye
únicamente `bootstrap`, `server/` y `shared/`; CI rechaza el PCK si encuentra
rutas visuales o del cliente.

## Frecuencias

- reloj de salas y eventos: 20 ticks/s;
- estados físicos del propietario: hasta 20/s;
- snapshots: 10/s;
- canal 0 fiable: sesión, reconexión y ronda;
- canal 1 `unreliable_ordered`: estados propietarios y snapshots;
- canal 2 fiable: eventos críticos.

Un estado propietario ocupa 22 bytes. El snapshot ocupa 24 bytes más 24 por
jugador remoto. Para dos jugadores cada destinatario recibe 48 bytes, sin slots
vacíos; el snapshot interno de dos jugadores usado por pruebas ocupa 72 bytes.

## Reconexión

Una desconexión conserva identidad, token, posición, velocidad, vida,
puntuación y última secuencia durante 60 segundos. Un nuevo `peer_id` con el token
correcto recupera el mismo `player_id`. El lobby crea hasta cinco salas dentro
del proceso, cada una con un máximo de cinco sesiones. Sólo el anfitrión puede
iniciar, se requieren al menos dos jugadores y todos deben confirmar `ready`;
si éste se desconecta, el rol pasa al siguiente jugador conectado. El servidor
conserva sólo el índice lógico de personaje, nunca su modelo o material.

Cada inicio ejecuta exactamente un minijuego. Al finalizar, la sala permanece
en resultado hasta que un jugador pide volver; nunca encadena otro modo. La
misma sala conserva identidad, puntuación acumulada y progreso, mientras limpia
los estados `ready` y restaura el cuerpo para el próximo minijuego. La RPC de
sala incluye sólo índices y cifras; nunca recursos visuales.

## Medición

Cada cinco segundos se imprime una línea `SERVER_METRICS` con CPU lógica,
memoria estática, bytes/s de aplicación y estados aceptados/rechazados. La
prueba ARM64 del modelo propietario con servidor, jugador y observador midió
25,02 MiB, 0,66 % de CPU lógica, 652 B/s recibidos y 1.087 B/s enviados.

Con la sala completa, los cinco clientes reciben snapshots y confirmaciones de
relay. En una medición ARM64 anterior el servidor usó 24,9 MiB y 1,24 % de CPU mientras
compartía el teléfono con cinco procesos cliente. La captura UDP/IP del VPS
midió 10,7 KiB/s salientes totales, incluidos ENet, UDP, IP, conexión y
keepalive: alrededor de 2,1 KiB/s descargados por cliente. A 20 estados/s, el
techo calculado de subida es aproximadamente 1,0 KiB/s por cliente incluyendo
cabeceras.

El servicio versionado fija `MemoryHigh=64M`, `MemoryMax=96M`, 35 % de un
núcleo y 32 tareas. El margen de CPU sirve para recuperar un tick tardío sin
reducir la frecuencia de juego.
