# OneProyect

Graybox 3D para Android orientado a teléfonos de gama baja. Usa Godot 4.7.1,
GDScript y el renderer Compatibility/OpenGL.

## Controles

- Escritorio: WASD o flechas para moverse, ratón para cámara, Espacio para
  saltar, `P`/Escape para pausa y `R` para reiniciar.
- Android: joystick izquierdo, arrastre en la mitad derecha para cámara y botón
  **SALTO**. Pausa y reinicio están en la barra superior.

El objetivo inicial es alcanzar el cilindro verde. El contador superior muestra
FPS y tiempo aproximado por frame.

## Exportación reproducible

El workflow `Android debug APK` fija Godot 4.7.1 y verifica los SHA-256 de los
binarios y export templates oficiales. Genera APK separados:

- `oneproyect-debug-arm64.apk`: teléfonos modernos, incluido el POCO X7 Pro.
- `oneproyect-debug-arm32.apk`: teléfonos antiguos de 32 bits.

Se ejecuta en pushes a `main`/`agent/graybox` y manualmente desde GitHub Actions.
