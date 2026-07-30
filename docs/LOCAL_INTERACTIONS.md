# Contrato de interacciones locales

Cada objeto declara una única categoría física:

| Categoría | Cuerpo Godot | Responsabilidad | Referencia |
| --- | --- | --- | --- |
| Estático | `StaticBody3D` | Nunca se mueve | muro |
| Móvil programado | `AnimatableBody3D` | Sigue una trayectoria y transporta cuerpos | plataforma |
| Movible | `RigidBody3D` | Responde a masa, impulsos y contactos | cajas, balón, piedra |

No se cambia la transformación de un `RigidBody3D` cada frame. Los impactos
usan impulsos puntuales; los reinicios son teletransportes esporádicos con el
cuerpo congelado y velocidades en cero. Modelo y colisión conservan origen,
escala uniforme y planta coincidentes.

El personaje transfiere una fuerza limitada al caminar contra un objeto
movible. Dos `ShapeCast3D` orientados con la cámara seleccionan y confirman la
acción. El primero es ancho y tolera la imprecisión táctil al decidir el texto;
el segundo representa el alcance corto del pie o la mano:

- **EMPUJAR** para cajas y cuerpos movibles genéricos;
- **PATEAR** para el balón de 44 cm y 0,43 kg;
- **TOMAR** para la piedra pequeña de 28 cm y 0,32 kg;
- **LANZAR** mientras la piedra está equipada.

La patada no aplica el impulso al presionar el botón. Primero inicia su
animación y vuelve a comprobar el contacto al pasar el pie; si el balón salió
del sondeo, la patada falla. La piedra se congela y desactiva su colisión
solamente mientras está equipada, y recupera su `RigidBody3D` al lanzarse.
La piedra pequeña tiene una excepción de colisión con su propietario: caminar
no la empuja ni bloquea al personaje. Continúa chocando normalmente con el
suelo y el mundo cuando se lanza. Las pruebas automatizadas cubren contacto al
caminar, patada acertada, patada fallida, cambio visible del botón, piedra
ignorada al caminar, equipamiento, lanzamiento y restauración.

`CharacterBody3D` no expone masa ni transmite por sí mismo fuerza a un
`RigidBody3D`. El contrato le asigna al personaje una masa de referencia de
70 kg únicamente para ese puente: con la normal y la velocidad relativa que
reporta `move_and_slide()`, se calcula la masa efectiva de los dos cuerpos y se
entrega el impulso a `RigidBody3D`. A partir de allí Godot resuelve movimiento,
gravedad, fricción, rebote y rotación. No existe una simulación paralela.

La elección sigue las clases oficiales:

- [RigidBody3D](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html)
  para objetos empujables;
- [AnimatableBody3D](https://docs.godotengine.org/en/stable/classes/class_animatablebody3d.html)
  para plataformas, puertas y puentes controlados.

## Vehículos

El auto no se añadirá como otro objeto genérico. Tendrá primero una pista de
laboratorio y pruebas de aceleración, frenado, giro, vuelco, reinicio y coste.
La propia documentación de
[VehicleBody3D](https://docs.godotengine.org/en/stable/classes/class_vehiclebody3d.html)
advierte problemas conocidos y que no está pensado para física realista. Para
este juego de gama baja se evaluará un controlador arcade pequeño sobre
`RigidBody3D` o `CharacterBody3D` antes de adoptar `VehicleBody3D`.
