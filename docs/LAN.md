# LAN nativa

La sesión LAN utiliza la API multijugador de alto nivel de Godot 4 con
`ENetMultiplayerPeer` sobre UDP. No usa el VPS ni el cliente de salas remoto.

## Puertos

- `9998/UDP`: partida ENet dentro de la red local.
- `9997/UDP`: anuncios de descubrimiento por broadcast.

Si el router o Android bloquean el broadcast, el jugador puede escribir la IP
privada que muestra el anfitrión. No se necesita abrir puertos en Internet.

## Responsabilidades iniciales

- Cada teléfono controla y presenta inmediatamente su propio personaje.
- Los estados de personajes se envían hasta 20 veces por segundo por el canal
  `unreliable_ordered` 1.
- El anfitrión simula los `RigidBody3D` que afectan a la ronda y publica sus
  estados 15 veces por segundo por el canal `unreliable_ordered` 2.
- Patadas e interacciones determinantes llegan al anfitrión por el canal
  fiable 2.
- Sala, selección, jugadores, estado listo e inicio usan el canal fiable 0.
- Todos reciben el mismo recurso de minijuego y la misma semilla de ronda.

El objetivo de esta etapa es validar en dispositivos reales movimiento,
colisiones y física compartida. La autoridad por evento de Corona, Bomba y
Tornado se puede endurecer después de observar la prueba LAN sin cambiar el
controlador local.
