# Dirección de interfaz: Tarjetas claras

Dirección elegida el 2026-08-01 para la siguiente capa de UX.

## Principio

La interfaz usa paneles 2D nativos de Godot en vez de imágenes de interfaz.
`Control`, contenedores y `StyleBoxFlat` resuelven tamaños, bordes y estados sin
texturas, shaders ni cámaras extra. Esto mantiene la UI nítida y barata en
teléfonos de gama baja.

## Sala

La sala Local/LAN adapta la composición aprobada en
`UI_DISENO_03_TARJETAS_CLARAS.png` y se compone de cuatro regiones:

```text
cabecera blanca: sala · anfitrión · puntos de sesión
├── tarjeta protagonista: icono, minijuego, descripción y selectores
├── carrusel de tarjetas: nombre · personaje · puntos · listo
└── acciones: volver · chat futuro · listo · iniciar
```

- Cada jugador usa una tarjeta blanca 2D con silueta dibujada, color de slot,
  nombre, personaje, puntos y estado. No usa un `SubViewport` ni un modelo 3D
  adicional.
- Los puntos son de sesión, no experiencia persistente.
- Verde significa listo; turquesa acción principal; coral destaca selección e
  información del anfitrión; azul grisáceo identifica navegación secundaria.
- El carrusel mantiene tarjetas legibles para ocho participantes sin reducir
  fuentes ni apilar textos verticalmente; en pantallas estrechas se desplaza.
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
