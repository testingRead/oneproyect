# Estado de validación de la base local

No se usa la palabra “aprobado” para una fase que aún requiere tacto o imagen
en el dispositivo. Esta tabla es el corte reproducible del 2026-07-30.

| Fase | Estado | Evidencia |
| --- | --- | --- |
| Aislamiento | Aprobada | Arranque `--local-development` sin nodo `Network`; “JUGAR LOCAL” desconecta y abre el mismo laboratorio |
| Inventario | Aprobado | Clasificación A/B/C/D en `LOCAL_BASE_AUDIT.md`; escena heredada congelada |
| Escala | Aprobada técnicamente | Un contrato ejecutable; referencias permanentes; prueba Linux y ARM64 |
| Personaje estándar | Base aprobada | Colisión, origen, pies y animación aprobados en el POCO |
| Variantes baja/alta | Estructura validada | Misma escena/controlador y origen; aún no habilitadas para uso |
| Locomoción | Base aprobada | Caminar, salto, cámara, pendiente, empuje y plataforma probados táctilmente |
| Límites | Candidata | Costa física permanente; 30/60/100 m son zonas lógicas con paredes internas opcionales |
| Objetos | Base aprobada | Mano/pie independientes; patada con fallo real y piedra equipable/lanzable |
| Mapa modular | Primer minijuego | `campo_futbol_local` empaqueta cancha, cinco spawns, portería y balón físico |
| Evento de referencia | Conservado y aislado | El pool anterior no se ejecuta ni se mezcla con la práctica de fútbol |
| Ronda local | Aprobada técnicamente | Ocho ciclos completos y una cancelación vuelven al conteo base sin residuos |
| NPC | Pendiente | No implementado |
| Reintegración multijugador | Bloqueada intencionalmente | Espera aprobación de las capas locales |

## Ejecución reproducible

```bash
godot --headless --path . --script res://tests/local_base_test.gd
godot --headless --path . --script res://tests/local_round_test.gd
godot --path . -- --local-development
```

Resultado actual en Linux y ARM64:

```text
LOCAL_BASE_OK nodes=99 objects=0 run_speed=6.00
jump_height=1.41 area=30
LOCAL_FOOTBALL_OK repeats=8 score=3-1 baseline_nodes=99 phases=7
```

El salto objetivo es 1,35 m; la diferencia observada hasta 1,41 m corresponde
a la integración discreta de 60 Hz y está dentro de la tolerancia inicial de
0,14 m. Se decidirá si se ajusta sólo después de probar su sensación en Android.

## Capturas OpenGL estandarizadas

Estas imágenes se generaron a 960 × 540 con Compatibility/OpenGL en Xvfb y
llvmpipe. Sirven como referencia visual determinista, no sustituyen la captura
del POCO.

- [01 personaje frontal](validation/local_base/phase_character/01_personaje_frontal.png)
- [02 personaje lateral](validation/local_base/phase_character/02_personaje_lateral.png)
- [03 pies en suelo](validation/local_base/phase_character/03_pies_en_suelo.png)
- [04 personaje corriendo](validation/local_base/phase_character/04_personaje_corriendo.png)
- [05 personaje saltando](validation/local_base/phase_character/05_personaje_saltando.png)
- [06 personaje en pendiente](validation/local_base/phase_character/06_personaje_en_pendiente.png)
- [07 límite pequeño](validation/local_base/phase_character/07_limite_pequeno.png)
- [08 límite grande](validation/local_base/phase_character/08_limite_grande.png)
- [09 objeto impactando](validation/local_base/phase_character/09_objeto_impactando.png)
- [10 fin de ronda limpio](validation/local_base/phase_character/10_fin_de_ronda_limpio.png)

La captura 10 se toma después de un ciclo real acelerado. La prueba asociada
verifica además que no queden mapas montados, balones, objetos de ronda,
señales repetidas ni temporizadores capaces de reactivar una ronda cancelada.
