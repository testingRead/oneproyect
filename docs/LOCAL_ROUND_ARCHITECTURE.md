# Contrato local de mapa y ronda

Esta capa funciona sin `Network` y no modifica la arquitectura ENet existente.
Su objetivo es que mapas, eventos y rondas puedan aprobarse en un cliente antes
de decidir qué resultados necesitarán autoridad remota.

## Responsabilidades

- `MinigameMapDefinition`: datos inmutables del contenido; no ejecuta física.
- `LocalMapHost`: monta una construcción para la semilla y la elimina completa.
- `LocalEventHost`: conserva tres meteoritos y tres marcas de peligro
  preasignados, los presenta de forma escalonada y los reutiliza.
- `LocalRoundController`: único dueño de fases, tiempos, bloqueo de controles y
  limpieza.
- `LocalBaseCharacter`: movimiento e impulsos inmediatos; desconoce mapas,
  rondas y red.

El mapa declara:

- `footprint` y `playable_area_index`;
- puntos de aparición, zonas seguras, eventos y navegación;
- objetos disponibles;
- desastres y minijuegos compatibles;
- nombres de slots modulares.

La semilla convierte cada slot en una variante binaria reproducible. Por ahora
los slots de la isla de laboratorio controlan habitación lateral, puente,
puerta bloqueada y distribución de cajas. No existe generación procedural
ambiciosa.

## Ciclo y limpieza

```text
PREPARE → RULES → COUNTDOWN → ACTIVE → RESULT → CLEANUP → IDLE
```

`stop_and_clean()` incrementa una generación interna. Todo temporizador viejo
comprueba esa generación al despertar, por lo que una ronda cancelada no puede
continuar ni reactivar contenido. La prueba ejecuta ocho rondas y una
cancelación; todas deben mostrar tres advertencias y volver exactamente al
mismo conteo de nodos.

## Autoridad futura

- mapa, semilla, fase, daño decisivo y resultado: autoridad de sesión;
- movimiento propietario: predicción local y corrección sólo cuando haga falta;
- animación, audio, partículas y fragmentos: cada cliente;
- meteorito lógico importante: autoridad;
- modelo, estela y fragmentos del meteorito: local.

Esta clasificación documenta el destino futuro, pero el laboratorio sigue
siendo completamente local hasta su aprobación en el POCO.

La zona de evento no implica una pared. En la isla de referencia, la costa es
el límite físico y el rectángulo 30/60/100 sólo dimensiona apariciones y reglas.
Un modo cerrado, como fútbol o arena, puede optar explícitamente por
`PHYSICAL_AREA`.

La antigua inundación central no será la referencia futura. Un tsunami debe
nacer fuera de la costa, atravesar la isla y consultar la huella del mapa; se
implementará después de aprobar el meteorito y su limpieza.
