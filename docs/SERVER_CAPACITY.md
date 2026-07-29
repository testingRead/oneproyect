# Capacidad del servidor

## Decisión de lenguaje

El servidor permanece en GDScript tipado durante esta etapa. El proceso
headless consume aproximadamente 25 MiB aun sin jugadores; cambiar las pocas
reglas a C++ o Rust no elimina ese coste fijo y añadiría otra cadena de
compilación. Godot indica además que los tipos estáticos permiten usar
operaciones optimizadas.

Sólo se considerará mover un módulo caliente a GDExtension después de encontrar
un cuello de botella reproducible con el profiler. La interfaz `shared/` permite
hacerlo sin cambiar los RPC ni las escenas del cliente.

Referencias oficiales:

- [Tipado estático de GDScript](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html)
- [Lenguajes de Godot](https://docs.godotengine.org/en/stable/getting_started/step_by_step/scripting_languages.html)
- [ENetMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html)

## Costes actuales

El transporte frecuente conserva buffers `PackedByteArray` por destinatario.
Un estado subido ocupa 22 bytes. Con cinco jugadores, cada cliente recibe
snapshots de 120 bytes a 10 Hz. El tráfico de aplicación es aproximadamente
1,17 KiB/s por jugador antes de cabeceras UDP/ENet.

`tests/server_capacity_benchmark.gd` ejecuta el reloj, eventos y construcción
de snapshots sin arrancar procesos cliente. Una medición en el VPS produjo:

| Salas | Jugadores | CPU lógica del núcleo | Salida calculada |
| ---: | ---: | ---: | ---: |
| 1 | 5 | 0,056 % | 5,86 KiB/s |
| 5 | 25 | 0,601 % | 29,30 KiB/s |
| 20 | 100 | 1,235 % | 117,19 KiB/s |
| 50 | 250 | 5,173 % | 292,97 KiB/s |

No incluye el coste del socket ENet ni del sistema operativo, por lo que sirve
para comparar cambios del núcleo, no como promesa de capacidad pública. La
prueba real de cinco clientes midió 24,66 MiB y 0,203 % de CPU lógica.

## Optimizaciones consolidadas

- Una sala no crea procesos, escenas visuales ni físicas por jugador.
- Los snapshots reutilizan buffers y omiten la transformación del destinatario.
- Las sesiones desconectadas se purgan una vez por segundo, no 20 veces.
- Al salir o expirar un jugador se elimina su buffer de snapshot. Esto evita
  crecimiento de memoria en salas reutilizadas durante muchas partidas.
- Las listas de sala, perfiles y clasificaciones usan RPC fiables sólo cuando
  cambian; movimiento y snapshots siguen en `unreliable_ordered`.

## Próximo límite

Se propone pasar de cinco a **seis jugadores por sala** cuando se diseñe el
primer modo por equipos. Seis permite 3 contra 3 y también reglas 2 contra 2
dejando espectadores o suplentes. El máximo real de una experiencia debe
declararse en sus metadatos: un duelo puede pedir 2, fútbol 4 o 6, y una
supervivencia aceptar hasta 6.

El número de salas será configurable y la interfaz deberá usar una lista con
scroll antes de superar las cinco actuales. Aumentar constantes sin esa
interfaz y sin una prueba ENet real ocultaría salas y no sería una
consolidación segura.
