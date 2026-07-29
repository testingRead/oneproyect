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

- simulación autoritativa: 20 ticks/s;
- input máximo aceptado: uno por jugador y tick;
- snapshots: 10/s;
- canal 0 fiable: sesión, reconexión y ronda;
- canal 1 `unreliable_ordered`: input y snapshots;
- canal 2 fiable: eventos críticos.

Un input ocupa 12 bytes. El snapshot ocupa 20 bytes más 24 por jugador
conectado. Para dos jugadores son 68 bytes, no 140 con tres slots vacíos.

## Reconexión

Una desconexión conserva identidad, token, posición, velocidad, vida,
puntuación y último input durante 60 segundos. Un nuevo `peer_id` con el token
correcto recupera el mismo `player_id`. El lobby crea hasta cinco salas dentro
del proceso, cada una con un máximo de cinco sesiones. Sólo el anfitrión puede
iniciar y se requieren al menos dos jugadores; si éste se desconecta, el rol
pasa al siguiente jugador conectado.

## Medición

Cada cinco segundos se imprime una línea `SERVER_METRICS` con CPU lógica,
memoria estática, bytes/s de aplicación e inputs aceptados/rechazados. La prueba
ARM64 en el POCO con servidor y dos clientes midió aproximadamente 24,8 MiB,
0,73 % de CPU, 0,78 KiB/s salientes y ningún input rechazado. La prueba x86_64
del VPS midió 24,8 MiB, 0,12 % de CPU y 0,80 KiB/s salientes agregados durante
conexión, movimiento y reconexión.

Con la sala completa, los cinco clientes recibieron snapshots autoritativos y
ACK sin fallos. En ARM64 el servidor usó 24,9 MiB y 1,24 % de CPU mientras
compartía el teléfono con cinco procesos cliente. La captura UDP/IP del VPS
midió 10,7 KiB/s salientes totales, incluidos ENet, UDP, IP, conexión y
keepalive: alrededor de 2,1 KiB/s descargados por cliente. A 20 inputs/s, el
techo calculado de subida es aproximadamente 1,0 KiB/s por cliente incluyendo
cabeceras.

El servicio versionado fija `MemoryHigh=64M`, `MemoryMax=96M`, 35 % de un
núcleo y 32 tareas. El margen de CPU sirve para recuperar un tick tardío sin
reducir la frecuencia de juego.
