# Base modular de OneProyect

La escena principal conserva cinco sistemas estables:

- `GrayboxPlayer`: movimiento, cámara, salud, hitboxes y API de daño;
- `DisasterController`: reloj y estados de ronda, sin reglas de un modo;
- módulos `MinigameMode`: reglas y recursos exclusivos de cada minijuego;
- `ModeMapHost`: activa y reutiliza mapas sin reemplazar jugador, HUD o red;
- `Network`: relay de instantáneas y eventos pequeños validados.

## Añadir un minijuego

1. Crear un script que herede
   `res://scripts/minigames/minigame_mode.gd`.
2. Configurar `mode_id`, duración y textos en `_ready()`.
3. Implementar solamente `begin_round`, `tick_round` y `finish_round`.
4. Preasignar pools y recursos en `_ready`; no instanciar objetos en cada frame.
5. Añadir el módulo como hijo directo de `World/DisasterController`. El orden de
   esos hijos define la rotación de rondas; el controlador no se modifica.

`tick_round` recibe `authoritative`. Un modo local puede ignorarlo. En línea,
solamente el cliente elegido como host debe generar azar o eventos. Si un modo
necesita un evento de red nuevo, se añade un RPC pequeño y validado a `Network`;
no debe sincronizar físicas completas.

## Añadir un mapa exclusivo

El módulo puede asignar una `PackedScene` a `map_scene`. Su raíz debe ser
`Node3D`. Un `Marker3D` del grupo persistente `player_spawn` determina el punto
de aparición.

`ModeMapHost` instancia esa escena una vez, la conserva en caché y desactiva
procesamiento y colisiones del mapa anterior. Al volver a Plaza Caos restaura el
mapa predeterminado. Esto evita reconstruir jugador, cámara, controles, HUD,
perfil y conexión en cada ronda.

## Añadir una variante de personaje

Los nombres, colores y reglas de desbloqueo están centralizados en
`scripts/characters/character_catalog.gd`. Proporciones, material, animación,
sombras y máscara de miembros viven en
`scripts/characters/humanoid_rig.gd`.

El jugador local, los avatares remotos y la previsualización consumen esas dos
fuentes. Una variante compatible con el rig se añade al catálogo y a
`apply_proportions`; no se duplica animación ni código de red. Una silueta con
otro esqueleto deberá implementar la misma interfaz visual antes de incorporarse
al catálogo.

## Contratos que no deben romperse

- El perfil Baja mantiene una luz como máximo, sin sombra ni posprocesamiento.
- Las piezas desprendidas, meteoritos, onda y agua son pools reutilizables.
- Las instantáneas de red son posición, orientación y una máscara corporal de
  7 bits; nunca se transmite una escena.
- Una escena de modo no accede directamente al HUD.
- La lógica del mapa no modifica `GrayboxPlayer`; usa sus métodos públicos.
- Cada modo y mapa nuevo debe ampliar `tests/smoke_test.gd`.
