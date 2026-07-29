# OneProyect

Juego 3D de supervivencia a desastres para Android orientado a teléfonos de
gama baja. Usa Godot 4.7.1, GDScript y el renderer Compatibility/OpenGL.

## Controles

- Escritorio: WASD o flechas para moverse, ratón para cámara, Espacio para
  saltar, `P`/Escape para pausa y `R` para reiniciar.
- Android: toda la mitad izquierda acepta un joystick flotante y toda la
  derecha queda para mirar, salvo los botones **SALTO** y **EMPUJAR**.
  El empujón alcanza solamente a un jugador cercano frente a la cámara.

La primera arena, **Plaza Caos**, alterna tres desastres:

- lluvia de meteoritos con marcas, refugios, daño e impulso físico;
- pulso sísmico, un único anillo reutilizable que debe saltarse o evitarse
  subiendo a la plataforma central.
- inundación ascendente, un único plano de agua que obliga a buscar altura.

Los techos bloquean físicamente las explosiones: refugiarse es una mecánica real,
no solamente decorativa. Ninguno de los dos modos crea nodos durante la ronda.
El contador superior muestra FPS y tiempo aproximado por frame. El daño tiene
respuesta visual y vibración breve en Android; una racha de rondas y el récord
personal guardado dan un objetivo inmediato sin añadir recursos pesados.

El menú guarda nombre, personaje, sonido, vibración, cámara en primera/tercera
persona, sensibilidad, límite de 30/45/60 FPS y cinco perfiles de calidad. Los
perfiles reutilizan los mismos recursos: escalan antialiasing y sombras sin
meter cinco copias de cada textura en el APK. Cuatro variantes low-poly son
gratuitas; la variante dorada requiere cinco victorias multijugador.

## Multijugador de prueba

El botón **CONECTAR** entra a una sala ENet/UDP de hasta cinco personas. Cada
jugador tiene nombre y color, y los avatares remotos se interpolan a partir de
10 actualizaciones de posición por segundo.

Los empujones se envían como eventos fiables pequeños únicamente al jugador
objetivo. Las victorias multijugador se guardan por separado de las rondas
locales; por ahora son progreso local de prototipo, no una economía segura.

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
Las decisiones de escalado y persistencia están en
[docs/QUALITY_AND_PROGRESSION.md](docs/QUALITY_AND_PROGRESSION.md).
