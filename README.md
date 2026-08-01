# OneProyect

Juego 3D de supervivencia a desastres para Android orientado a teléfonos de
gama baja. Usa Godot 4.7.1, GDScript y el renderer Compatibility/OpenGL.

## Base local en consolidación

La ruta oficial de desarrollo es ahora una isla-laboratorio independiente del
servidor. **JUGAR LOCAL** abre esa escena; desde CLI puede iniciarse sin crear
siquiera el singleton de red:

```bash
godot --path . -- --local-development
```

La isla conserva un mundo físico de 150 × 150 m. La costa es el límite físico
natural y la escena local ya no contiene patio, cajas, rampas, piedras ni
referencias de laboratorio. Sus medidas y pruebas están en:

- [contrato de escala](docs/LOCAL_BASE_SCALE.md);
- [auditoría A/B/C/D](docs/LOCAL_BASE_AUDIT.md);
- [pruebas y capturas](docs/LOCAL_BASE_VALIDATION.md).
- [contrato de interacciones](docs/LOCAL_INTERACTIONS.md).

Cada minijuego ejecuta preparar → reglas → cuenta regresiva → actividad →
resultado → limpieza. El catálogo descubre automáticamente los recursos de
`data/minigames`: fútbol de rebote, corona central, bomba de relevo, tornado,
Bateball y arena de tiro. Cada uno monta únicamente su mapa y objetos; al
terminar vuelve a la misma sala o al menú sin conservar nodos, temporizadores ni
señales de la ronda.

La arena de tiro es el primer modo individual completo: primera persona, ocho
spawns, tres perfiles de arma, cargador/recarga, hitscan, cinco eliminaciones y
tres bots ligeros cuando se juega en solitario. En LAN el anfitrión confirma
impactos, vida, munición, bajas y reapariciones, mientras cada teléfono conserva
movimiento, cámara, trazadores, sonido y animación inmediatos.

La compilación local reproducible del laboratorio se realiza íntegramente en
Termux con [`tools/android-native/build-termux.sh`](tools/android-native/README.md).
No usa ADB ni el VPS, compila sólo ARM64, valida el APK y lo copia directamente
a Downloads.

## Controles

- Escritorio: WASD o flechas para moverse, ratón para cámara, Espacio para
  saltar, `P`/Escape para pausa y `R` para reiniciar.
- Android: la mitad izquierda mueve y la derecha controla la vista o la mira.
  Los botones cambian por modo: salto y patada en fútbol, bate/disparo en
  Bateball y disparar/recargar en shooter. Mantener **DISPARAR** respeta la
  cadencia sin confundir toques del joystick o de cámara con tiros.

Los modos con equipos alternan slots y conservan spawns y miradas coherentes;
los individuales orientan todos los puntos de aparición hacia el centro del
escenario. Los nombres del shooter respetan profundidad y no revelan rivales
detrás de coberturas.

El menú guarda nombre, personaje, sonido, vibración, cámara en primera/tercera
persona, sensibilidad, límite de 30/45/60 FPS y tres perfiles de calidad. Las
opciones se muestran como listas completas y el personaje tiene una
previsualización 3D. Los perfiles reutilizan los mismos recursos: escalan
antialiasing y sombras sin duplicar texturas en el APK. Cuatro variantes
low-poly son gratuitas; la variante dorada requiere cinco victorias
multijugador.

El personaje usa una animación procedural ligera y ocho zonas de impacto. El
daño localizado puede desprender piezas estilizadas del traje; éstas provienen
de un pool físico fijo y su estado se sincroniza como una máscara compacta. Una
o dos piernas perdidas reducen el movimiento y sin brazos no se puede empujar.
Reaparecer restaura el cuerpo completo.

## Base modular

El ciclo de ronda no contiene reglas concretas de desastres. Descubre módulos
hijos que implementan el contrato común `MinigameMode`; Meteoritos, Pulso e
Inundación son tres módulos independientes. Cada módulo puede declarar su propia
duración, textos, reglas y una escena de mapa opcional.

Los mapas exclusivos se cargan una sola vez, quedan en caché y usan un
`Marker3D` del grupo `player_spawn`. El jugador, cámara, HUD, perfil y red se
mantienen entre modos. El catálogo y rig humanoide también son compartidos por
el jugador local, los avatares remotos y la previsualización.

La guía para añadir modos, mapas y personajes sin acoplarlos al núcleo está en
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Menú y multijugador de prueba

El arranque muestra dos rutas separadas. **JUGAR LOCAL** abre la isla-laboratorio
sin conectarse a ningún servidor. **MULTIJUGADOR** abre un lobby ENet/UDP con hasta
cinco salas simultáneas de cinco personas cada una. El creador es el anfitrión
de la sala y puede iniciar cuando hay entre dos y cinco jugadores y todos han
marcado **LISTO**; si se desconecta, el siguiente jugador conectado hereda ese
rol. El personaje se elige en la sala, queda bloqueado al confirmar y no puede
cambiarse durante la partida.

Cada jugador tiene nombre y color, y los avatares remotos se interpolan a
partir de 10 actualizaciones de posición por segundo. La misma instantánea
incluye orientación y estado corporal, sin enviar nodos ni físicas visuales por
red. Al cambiar de la sala al mapa, el cliente reconstruye desde el estado
conservado todos los avatares que ya estaban conectados.

Los empujones se envían como eventos fiables pequeños únicamente al jugador
objetivo. Cada ronda publica vida, puntos y clasificación; al terminar la
partida se puede volver a la misma sala, preparar otra partida o salir al
lobby. La sala muestra nombre, personaje, estado listo, victorias y experiencia
de cada jugador.

Victorias, XP, partidas, rondas y supervivencias multijugador se guardan por
separado del modo local. Las recompensas llevan identificador de partida y
ronda para no duplicarse al reconectar; siguen siendo progreso local de
prototipo, no una economía segura.

El VPS escucha en UDP `9999` y es autoritativo para sesión, fase, clasificación,
puntuación, reconexión y eventos compartidos. No carga mapas visuales, cámaras,
luces, texturas, animaciones, partículas ni audio. En esta base de prototipo,
cada cliente resuelve la física completa de su personaje y el servidor valida
y retransmite resultados compactos sin devolverle su propia transformación.
Los demás clientes interpolan esos estados; por eso el movimiento local no
depende del RTT.

## Exportación reproducible

El workflow `Android debug APK` fija Godot 4.7.1 y verifica los SHA-256 de los
binarios y export templates oficiales. Genera APK separados:

- `oneproyect-debug-arm64.apk`: teléfonos modernos, incluido el POCO X7 Pro.
- `oneproyect-debug-arm32.apk`: teléfonos antiguos de 32 bits.

Se ejecuta en pushes a `main`/`agent/graybox` y manualmente desde GitHub Actions.
Antes de exportar, CI ejecuta pruebas del menú y la arena, reglas de cinco salas,
una conexión de lobby con dos clientes, movimiento y reconexión autoritativos,
y una sala completa de cinco clientes con límites de memoria y tráfico. Las
builds de prueba usan una firma
estable guardada únicamente en GitHub
Actions Secrets, por lo que las siguientes versiones podrán instalarse como
actualizaciones sin cambiar la identidad de la aplicación.

CI reemplaza siempre una única prerelease pública `playtest-latest`; no crea
artifacts temporales ni acumula releases. Descargas directas:

- [APK ARM64 para teléfonos modernos](https://github.com/testingRead/oneproyect/releases/download/playtest-latest/oneproyect-debug-arm64.apk)
- [APK ARM32 para teléfonos antiguos](https://github.com/testingRead/oneproyect/releases/download/playtest-latest/oneproyect-debug-arm32.apk)

La ruta recomendada para exportar directamente en el teléfono está documentada
en [docs/ANDROID_LOCAL_BUILD.md](docs/ANDROID_LOCAL_BUILD.md).
Las decisiones de escalado y persistencia están en
[docs/QUALITY_AND_PROGRESSION.md](docs/QUALITY_AND_PROGRESSION.md).
Las mediciones y el plan de capacidad del servidor están en
[docs/SERVER_CAPACITY.md](docs/SERVER_CAPACITY.md).
