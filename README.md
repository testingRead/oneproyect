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
El contador superior muestra FPS y tiempo aproximado por frame.

## Exportación reproducible

El workflow `Android debug APK` fija Godot 4.7.1 y verifica los SHA-256 de los
binarios y export templates oficiales. Genera APK separados:

- `oneproyect-debug-arm64.apk`: teléfonos modernos, incluido el POCO X7 Pro.
- `oneproyect-debug-arm32.apk`: teléfonos antiguos de 32 bits.

Se ejecuta en pushes a `main`/`agent/graybox` y manualmente desde GitHub Actions.
Las builds de prueba usan una firma estable guardada únicamente en GitHub
Actions Secrets, por lo que las siguientes versiones podrán instalarse como
actualizaciones sin cambiar la identidad de la aplicación.

Los artifacts se conservan solamente 1 día para limitar almacenamiento.
