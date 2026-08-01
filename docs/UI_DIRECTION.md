# Dirección de interfaz: Sala Isla

Dirección elegida el 2026-08-01 para la siguiente capa de UX.

## Principio

La interfaz usa paneles 2D nativos de Godot en vez de imágenes de interfaz.
`Control`, contenedores y `StyleBoxFlat` resuelven tamaños, bordes y estados sin
texturas, shaders ni cámaras extra. Esto mantiene la UI nítida y barata en
teléfonos de gama baja.

## Sala

La sala Local/LAN reproduce la composición aprobada en
`UI_DISENO_01_SALA_ISLA.png` y se compone de cuatro regiones:

```text
cabecera: sala · jugadores/listos · estado
├── selección: minijuego y personaje local
├── roster: nombre · personaje · puntos de sesión · listo
└── acciones: volver · chat futuro · listo · iniciar
```

- Cada jugador usa una tarjeta 2D con número, silueta dibujada, color de slot,
  nombre, personaje, puntos y estado. No usa un `SubViewport` ni un modelo 3D
  adicional.
- Los puntos son de sesión, no experiencia persistente.
- Verde significa listo; turquesa acción principal; naranja información del
  anfitrión; rojo sólo abandonar/cancelar.
- El botón de chat es una carcasa de UX desactivada. No abre red ni conserva
  mensajes hasta que exista una sala remota que lo requiera.

## Reglas de crecimiento

1. Un sistema debe alimentar la interfaz existente; no duplicar perfiles,
   puntos, selección de personaje o estado de listo sólo para mostrar UI.
2. Las tarjetas se recrean al cambiar el lobby, nunca cada frame.
3. Nuevos minijuegos entran mediante el catálogo y el selector ya existente.
4. Las pantallas de juego reutilizarán la misma paleta, tipografía y botones,
   pero no deben cubrir controles táctiles ni información de juego crítica.

## Implementación

- `IslandUiTheme` concentra paleta, fuente, botones, selectores, entradas y
  `StyleBoxFlat`.
- `IslandUiArt` dibuja el fondo de isla, logotipo, siluetas e iconos de
  minijuego con primitivas 2D baratas.
- `menu_capture_test.gd` genera capturas reproducibles a 1280 × 720 del inicio,
  sala local y sala multijugador llena.
- La misma familia visual se aplica a joystick, botones de acción, punto de
  mira y paneles informativos dentro de la partida.

No se incluye la maqueta rasterizada dentro de la aplicación. La captura es
una referencia; la implementación final es adaptable y nativa.
