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
movible. La acción explícita **EMPUJAR** hace un sondeo corto en la dirección
de cámara y aplica un único impulso si encuentra un `RigidBody3D`. La prueba
automatizada cubre ambos caminos con el balón ligero y la piedra pesada; ya no
basta con verificar impulsos sintéticos aplicados directamente desde el test.

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
