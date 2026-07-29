# OneProyect

Juego 3D de supervivencia a desastres para Android orientado a teléfonos de
gama baja. Usa Godot 4.7.1, GDScript y el renderer Compatibility/OpenGL.

## Controles

- Escritorio: WASD o flechas para moverse, ratón para cámara, Espacio para
  saltar, `P`/Escape para pausa y `R` para reiniciar.
- Android: joystick izquierdo, arrastre en la mitad derecha para cámara y botón
  **SALTO**. Pausa y reinicio están en la barra superior.

La primera arena, **Plaza Caos**, ejecuta rondas de lluvia de meteoritos con
marcas de advertencia, refugios, daño, impulso físico y un pool fijo de objetos.
Los techos bloquean físicamente las explosiones: refugiarse es una mecánica real,
no solamente decorativa.
El contador superior muestra FPS y tiempo aproximado por frame.

## Multijugador de prueba

El botón **CONECTAR** entra a una sala ENet/UDP de hasta cinco personas. Cada
jugador tiene nombre y color, y los avatares remotos se interpolan a partir de
10 actualizaciones de posición por segundo.

El VPS escucha en UDP `9999` y actúa sólo como retransmisor. El teléfono con
mayor capacidad declarada simula la ronda y envía los eventos del desastre; a
igualdad de capacidad, el relay favorece una latencia al menos 40 ms mejor y
evita cambios pequeños que harían oscilar el rol. Si el host se desconecta, se
elige otro automáticamente. Así, la máquina pequeña no procesa el mapa, los
meteoritos ni las colisiones.

## Exportación reproducible

El workflow `Android debug APK` fija Godot 4.7.1 y verifica los SHA-256 de los
binarios y export templates oficiales. Genera APK separados:

- `oneproyect-debug-arm64.apk`: teléfonos modernos, incluido el POCO X7 Pro.
- `oneproyect-debug-arm32.apk`: teléfonos antiguos de 32 bits.

Se ejecuta en pushes a `main`/`agent/graybox` y manualmente desde GitHub Actions.
Antes de exportar, CI ejecuta una prueba de movimiento/colisiones/refugio y otra
con un servidor más dos clientes reales, verificando posiciones, elección de
host, meteoritos y sincronización de ronda. Las builds de prueba usan una firma
estable guardada únicamente en GitHub
Actions Secrets, por lo que las siguientes versiones podrán instalarse como
actualizaciones sin cambiar la identidad de la aplicación.

Los artifacts se conservan solamente 1 día para limitar almacenamiento.

La ruta recomendada para exportar directamente en el teléfono está documentada
en [docs/ANDROID_LOCAL_BUILD.md](docs/ANDROID_LOCAL_BUILD.md).
