# Servidor de sala

El servidor ejecuta únicamente `scenes/bootstrap.tscn` y el autoload de red.
Escucha con ENet en UDP `9999`, acepta un máximo de cinco clientes y no carga la
arena ni simula físicas.

El cliente declara una puntuación limitada basada en sus núcleos disponibles.
El relay entrega la simulación al teléfono con mayor puntuación y, entre
equivalentes, sólo cambia de host si otro mantiene al menos 40 ms menos de RTT.
Esto evita cargar el VPS y también evita que el rol oscile por variaciones
pequeñas de red.

El servicio versionado en `oneproyect-server.service` fija límites deliberados
para el VPS actual:

- memoria máxima: 192 MiB;
- CPU máxima: 35 % de un núcleo;
- reinicio automático sólo ante fallo;
- directorio del juego de sólo lectura.

La prueba `tests/network_probe.gd` levanta dos clientes completos. CI exige que
ambos intercambien nombres, posiciones, un meteorito y el estado de ronda antes
de generar los APK.
