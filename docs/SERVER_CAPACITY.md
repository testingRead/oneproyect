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

## Qué consume cada unidad

El transporte frecuente conserva buffers `PackedByteArray` por destinatario.
Un estado subido ocupa 22 bytes. Con cinco jugadores, cada cliente recibe
snapshots de 120 bytes a 10 Hz. El tráfico de aplicación es aproximadamente
1,17 KiB/s por jugador antes de cabeceras UDP/ENet.

La prueba `tests/server_memory_benchmark.gd` construye cien salas y quinientas
sesiones en un único proceso. La memoria estática incremental medida fue:

| Unidad | Memoria incremental |
| --- | ---: |
| Sala vacía | 7,15 KiB |
| Jugador esperando | 2,71 KiB |
| Caché activa de snapshot por jugador | 0,32 KiB |

Las cien salas, quinientas sesiones y sus cachés sumaron aproximadamente
2,18 MiB. El RSS no creció porque el asignador de Godot ya tenía páginas
reservadas. Esta cifra no incluye la memoria nativa interna que ENet reserve
para conexiones reales, por lo que se conserva margen operativo.
Hacer avanzar cien salas vacías durante diez segundos simulados consumió
aproximadamente 0,13 % de un núcleo; su coste CPU en espera es despreciable.

Conclusión: crear una sala vacía cuesta algo de RAM, pero muy poca CPU. Los
jugadores activos son el multiplicador importante porque generan inputs,
snapshots y destinatarios de red. La cantidad de objetos lógicos activos
(balón, proyectiles, zonas de daño) añade CPU y tráfico durante el minijuego.

## CPU y salida

`tests/server_capacity_benchmark.gd` ejecuta el reloj, eventos y construcción
de snapshots sin arrancar procesos cliente. Una medición repetida en el VPS
produjo:

| Salas | Jugadores | CPU lógica del núcleo | Salida calculada |
| ---: | ---: | ---: | ---: |
| 1 | 5 | 0,059 % | 5,86 KiB/s |
| 5 | 25 | 0,296 % | 29,30 KiB/s |
| 20 | 100 | 1,534 % | 117,19 KiB/s |
| 50 | 250 | 3,253 % | 292,97 KiB/s |

No incluye el coste del socket ENet ni del sistema operativo, por lo que sirve
para comparar cambios del núcleo, no como promesa de capacidad pública. La
prueba real con cinco salas y veinticinco procesos cliente simultáneos completó
25/25 conexiones, movimiento y confirmaciones. Durante el intervalo activo,
las métricas internas registraron aproximadamente 0,73 % de CPU lógica,
9,16 KiB/s recibidos y 27,70 KiB/s enviados. La medición externa del proceso,
que también incluye ENet y el despacho de RPC, quedó alrededor de 1,8 % de un
núcleo. El RSS no superó las páginas ya reservadas por el ejecutable usado en
la prueba. Ese método no se volverá a escalar en el VPS: el consumo fijo de
decenas de motores cliente contamina la medición y puede agotar la máquina.

## Presupuesto para minijuegos futuros

`tests/minigame_capacity_benchmark.gd` fuerza veinte salas y cien jugadores a
ejecutar a la vez tres cargas. No presupone que tendremos la suerte de repartir
modos livianos y pesados:

| Carga simultánea | Estado lógico adicional | CPU lógica | Salida de aplicación |
| --- | --- | ---: | ---: |
| Supervivencia actual | reglas y snapshots actuales | 1,25 % | 117,19 KiB/s |
| Fútbol | un balón autoritativo por sala | 1,25 % | 140,62 KiB/s |
| Shooter conservador | dos proyectiles activos por jugador | 1,85 % | 273,44 KiB/s |

Son escenarios sintéticos y no una promesa de producción. A la salida de
aplicación se le aplicará un margen de al menos 2× para cabeceras, retransmisión
fiable, picos de lobby y variación de red. Cada nuevo minijuego deberá declarar
su presupuesto de objetos autoritativos y superar este mismo benchmark antes
de entrar en rotación.

Marcadores, goles, munición y recarga son estados pequeños y eventuales; no
justifican sincronizar nodos visuales. Para el shooter se deberán agrupar
proyectiles en un paquete compacto por snapshot y limitar su número activo. El
cliente seguirá resolviendo partículas, trazadores, sonido y animación.

## Optimizaciones consolidadas

- Una sala no crea procesos, escenas visuales ni físicas por jugador.
- Los snapshots reutilizan buffers y omiten la transformación del destinatario.
- Las sesiones desconectadas se purgan una vez por segundo, no 20 veces.
- Al salir o expirar un jugador se elimina su buffer de snapshot. Esto evita
  crecimiento de memoria en salas reutilizadas durante muchas partidas.
- Las listas de sala, perfiles y clasificaciones usan RPC fiables sólo cuando
  cambian; movimiento y snapshots siguen en `unreliable_ordered`.

## Política de capacidad

Los máximos actuales de cinco salas por cinco jugadores son un límite de
producto, no el techo técnico medido. No se llenará la máquina hasta el 100 %:

- CPU sostenida objetivo: como máximo 50 % de un núcleo para el proceso.
- RSS objetivo: como máximo 60 % de la memoria disponible.
- Salida sostenida objetivo: como máximo 50 % del ancho de banda medido.
- Si cualquiera supera el objetivo, se dejan de crear salas; no se degrada el
  tick de una partida ya iniciada.
- Se observa p95/p99, no solamente el promedio, y se prueba el modo más pesado
  en todas las salas simultáneamente.

Todavía no se aumenta el límite público basándose sólo en la simulación. El
siguiente escalón de validación será 20 salas/100 clientes ENet reales con un
generador único. Cada cliente virtual tendrá su propio `SceneMultiplayer` y
`ENetMultiplayerPeer`, asignado a una rama independiente mediante
`SceneTree.set_multiplayer()`. El generador se ejecutará primero en el POCO y
después desde más de un origen de red. Así se miden buffers nativos, pérdida,
retransmisiones y ancho de banda real sin iniciar un motor por jugador.

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
