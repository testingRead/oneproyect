# Auditoría para reconstrucción local

Fecha de corte: 2026-07-30. Esta clasificación evita seguir ampliando la escena
multijugador mientras se aprueba una base física local.

## A. Base confirmada

- Godot 4.7.1, GDScript y Compatibility/OpenGL.
- Controles táctiles reutilizables: joystick izquierdo, mirada derecha y botón.
- `CharacterBody3D` como cuerpo lógico y cámara local inmediata.
- Exportación Android ARM64/ARM32, firma estable y pruebas ARM64.
- Transporte ENet, salas, sesiones y servidor dedicado. Se conservan sin
  intervenir en esta etapa.
- Caché de mapas y contrato de límites consultable.

## B. Experimentos útiles, aislados

- Minijuegos, mapas ampliados, armas, daño localizado y desmembramiento.
- Avatares orgánicos, ropa, especies y catálogo de ocho variantes.
- Calidad baja/media/alta, landmarks y decoración procedural.
- Modos shooter, dominio, drones, inundación, onda y meteoritos.

Permanecen disponibles para reutilización posterior, pero no forman parte de la
ruta oficial `LOCAL_DEVELOPMENT` ni se usarán para aprobar locomoción.

## C. Comportamientos accidentales por convertir en reglas

- Empujes y meteoritos que producen impulsos divertidos.
- Objetos físicos que pueden encadenar golpes.
- Balanceos exagerados del personaje.

No se eliminan como ideas, pero tampoco se conservan como parámetros opacos.
Cada uno volverá únicamente mediante una prueba y valores documentados.

## D. Residuos y soluciones competidoras

- Offsets de aparición `y = 1.2`, cápsula centrada y modelos con correcciones
  verticales diferentes.
- Geometría del personaje embebida dentro de `main.tscn`.
- Medidas repetidas entre escenas de mapa.
- Una UID huérfana de `shared/movement_rules.gd`, sin script correspondiente.
- La escena principal mezcla jugador, mapas, seis modos, features, audio, HUD,
  pools y red, por lo que no sirve como laboratorio de física.

La UID huérfana se elimina. La escena principal se conserva temporalmente sólo
como integración multijugador heredada. No recibirá nuevas mecánicas. La ruta
oficial pasa a ser:

```text
LOCAL_DEVELOPMENT
└── LocalDevelopmentLab
    ├── PhysicalWorld (isla y océano)
    ├── LocalPlayableArea (cuatro límites reutilizables)
    ├── LocalBaseCharacter
    ├── ScaleReferences
    └── TestCourse
```

Cuando la base sea aprobada, `main.tscn` instanciará el mismo
`LocalBaseCharacter` y dejará de mantener el controlador heredado.
