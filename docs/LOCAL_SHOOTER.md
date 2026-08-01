# Arena de tiro local y LAN

`shooter_local` reutiliza la base física oficial. No depende de la escena
multijugador antigua ni del servidor VPS.

## Regla aprobable

- todos contra todos;
- primera persona;
- el botón de disparo puede mantenerse pulsado y respeta la cadencia del arma;
- cinco eliminaciones para terminar antes del reloj de 60 s;
- respawn a los 1,6 s;
- cada jugador conserva vida, cargador, recarga y cadencia propias;
- el rival con más eliminaciones representa la comparación principal del HUD;
- en local aparecen tres rivales de práctica; en LAN se omiten automáticamente.

La semilla elige una de las tres armas compartidas: P9, C16 o T12. Cada perfil
declara daño, alcance, cadencia, cargador y recarga. La T12 realiza cinco rayos
cortos, pero un mismo objetivo sólo recibe una aplicación de daño por disparo.

## Responsabilidades

- `LocalBaseCharacter`: movimiento, cámara, origen/dirección de tiro y cuerpo;
- `BaseCharacterVisual`: arma en mano, pose, retroceso y recarga;
- `LocalShooterArena`: suelo, paredes, coberturas y líneas visuales;
- `LocalShooterHost`: munición, hitscan, vida, eliminaciones, respawn, bots y
  clasificación;
- `LocalRoundController`: fases, reloj y limpieza;
- `OneProjectLanSession`: transporte de acciones y confirmaciones.

El disparo local reproduce inmediatamente animación, trazador y sonido. En LAN
el anfitrión repite un raycast simplificado desde la posición recibida del
tirador y confirma daño, marcador de impacto, munición, recarga, reaparición y
clasificación mediante eventos fiables. El invitado no puede saltarse la
cadencia ni disponer de munición infinita: el anfitrión mantiene esos dos
estados compactos por `peer_id`.
Las posiciones continúan por el canal no fiable ya existente. No se crean
proyectiles físicos ni se envían texturas, efectos o audio.

Los ocho puntos de aparición miran al centro y se encuentran fuera de las
coberturas. Al reaparecer se restablecen orientación, vida y cargador; durante
los 1,6 segundos de eliminación el cuerpo y su colisión quedan desactivados.

## Presupuesto de gama baja

- geometría de cajas y cilindros de pocos segmentos;
- una luz global, sin sombras propias;
- diez trazadores preasignados;
- raycasts únicamente cuando alguien dispara;
- sonido mono de 11,025 kHz generado una vez;
- tres bots como máximo y sólo en práctica individual;
- etiquetas de vida simples, sin barras 3D complejas;
- limpieza por generación para impedir respawns de rondas anteriores.

## Validación

`tests/shooter_round_test.gd` comprueba escena, cámara, botones, mira, rivales,
arma P9, daño, eliminación, recarga automática, respawn y conteo exacto de
nodos después de limpiar. Las sondas LAN comprueban solicitud y retransmisión
fiable de `SHOOTER_SHOT`.
