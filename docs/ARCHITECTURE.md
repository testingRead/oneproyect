# Base modular de OneProyect

OneProyect separa el juego persistente de la experiencia que cambia en cada
ronda. Jugador, cámara, controles, HUD, perfil y conexión sobreviven. Un plan
pequeño selecciona las reglas, el mapa y las extensiones de la siguiente ronda.

Esta división sigue tres ideas usadas por motores y muestras grandes:

- escenas autocontenidas, dependencias explícitas y señales para reducir
  acoplamiento, como recomienda
  [Godot](https://docs.godotengine.org/en/4.0/tutorials/best_practices/scene_organization.html);
- estado de partida separado de estado de jugador, equivalente a `GameMode`,
  `GameState` y `PlayerState` del
  [Gameplay Framework de Unreal](https://dev.epicgames.com/documentation/en-us/unreal-engine/game-mode-and-game-state-in-unreal-engine);
- experiencias compuestas por features activables, como
  [Lyra](https://dev.epicgames.com/documentation/unreal-engine/lyra-sample-game-in-unreal-engine)
  y el sistema de
  [Game Features](https://dev.epicgames.com/documentation/en-us/unreal-engine/game-features-and-modular-gameplay-in-unreal-engine).

No se copian esas arquitecturas completas: esta versión conserva sólo los
límites útiles para un juego pequeño de cinco personas y teléfonos modestos.

## Capas estables

- `GrayboxPlayer`: movimiento, cámara, controles, salud, hitboxes y API de
  daño/empuje.
- `DisasterController`: presentación, reloj, estados de ronda y selección
  aleatoria. No contiene reglas de un minijuego concreto.
- `MinigameMode`: reglas y recursos exclusivos de un modo.
- `MinigameMapDefinition` y `ModeMapHost`: metadatos, compatibilidad, caché y
  activación de mapas.
- `ExperienceFeatureHost`: activa extensiones opcionales e inyecta referencias
  al jugador, mundo y HUD.
- `Network`: retransmite planes, instantáneas y eventos pequeños validados.
- `CharacterCatalog` y `HumanoidRig`: identidad visual compartida por jugador
  local, remoto y previsualización.

## Contrato de una ronda

Cada selección produce un diccionario que puede sincronizarse y reproducirse:

```text
mode_id + map_id + round_seed + feature_ids
+ player_profile_id + spawn_policy_id + spectator_policy_id
```

La red transmite esos identificadores y la semilla; nunca escenas ni materiales.
El servidor decide el plan y los clientes cargan los recursos locales
registrados bajo los mismos IDs. Cada teléfono simula la física de su personaje
y replica únicamente el resultado compacto.

- `mode_id`: reglas principales, por ejemplo meteoritos o duelo.
- `map_id`: escenario compatible.
- `round_seed`: azar determinista para posiciones, equipos u objetos.
- `feature_ids`: añadidos reutilizables como zombi, armas o baja gravedad.
- `player_profile_id`: velocidad, cámara y capacidades permitidas.
- `spawn_policy_id`: disperso, equipos, puntos fijos o aleatorio seguro.
- `spectator_policy_id`: cámara superior, libre o seguimiento de jugador.

Una política nueva debe registrarse por ID. No se añaden condicionales
específicos del minijuego a `game.gd`.

## Común, personalizado y único

`MinigameMode.ModeCategory` documenta tres grados de composición:

1. **Común**: pide etiquetas de mapa y rota con cualquier mapa compatible.
2. **Personalizado**: fija sólo lo necesario; puede reutilizar un mapa común y
   sumar una feature zombi, armas o controles distintos.
3. **Único**: puede fijar mapa, perfil, aparición, espectador y features, pero
   sigue usando el mismo contrato de ronda.

| Experiencia | Modo | Mapa | Features/perfiles |
| --- | --- | --- | --- |
| Meteoritos | `meteors` | `common`, `survival`, `open_sky` | perfil normal |
| Ola | `shockwave` | `common`, `elevation` | perfil normal |
| Infección | supervivencia | mapa común compatible | `zombie`, equipos |
| Duelo | `shooter` | mapa fijado o `combat` | armas, primera persona, spawns por equipo |
| Laberinto | `maze_escape` | mapa propio | trampas, spawns fijos, espectador superior |

## Añadir un minijuego

1. Crear un script que herede
   `res://scripts/minigames/minigame_mode.gd`.
2. Configurar ID, categoría, peso, duración, textos y etiquetas necesarias o
   bloqueadas.
3. Implementar `begin_round`, `tick_round` y `finish_round`.
4. Preasignar pools y recursos en `_ready`; no instanciar objetos cada frame.
5. Añadir el módulo como hijo directo de `World/DisasterController`.
6. Añadir cobertura a `tests/smoke_test.gd`.

`tick_round` recibe `authoritative`. En línea, el servidor genera azar y eventos
de reglas; la presentación y el contacto con el personaje propio se ejecutan en
cada cliente.

## Añadir un mapa

1. Crear una escena con raíz `Node3D`, colisiones y uno o más `Marker3D` del
   grupo persistente `player_spawn`.
2. Crear un `MinigameMapDefinition` con ID, etiquetas, peso, máximo de jugadores
   y `PackedScene`.
3. Registrar el recurso en `ModeMapHost.map_definitions`.

El host filtra por etiquetas requeridas/bloqueadas y cantidad de jugadores. Los
mapas no predeterminados se instancian una vez, se conservan en caché y se
desactivan junto con sus colisiones. El mapa no modifica al jugador ni al HUD.

## Añadir una feature

Una feature hereda `GameplayFeature`, declara un `feature_id` estable y recibe
un contexto en `activate`:

```gdscript
func activate(context: Dictionary) -> void:
    var player = context.player
    var world = context.world
    var plan = context.plan
```

Debe desconectar señales y devolver nodos reutilizables a su estado inicial en
`deactivate`. El host sólo mantiene activas las IDs pedidas por el plan
siguiente. Una feature opcional no altera permanentemente una escena común.

## Votación y espectadores

La futura votación ofrecerá dos o tres planes completos generados por el host,
no un mapa y un modo incompatibles por separado. Cada cliente enviará una
elección; el host desempatará con la semilla de sesión y publicará el ganador.

Al morir, el jugador cambia de vivo a espectador superior hasta terminar la
ronda. Conserva nombre, variante, puntuación y condición de eliminado, sin
destruir el controlador principal. Los futuros modos podrán sustituir esta
política por seguimiento libre o reaparición explícita.

## Contratos que no deben romperse

- Baja mantiene una luz como máximo, sin sombra ni posprocesamiento.
- Baja, Media y Alta cambian configuración y recursos compartidos; no duplican
  el juego ni requieren una APK por calidad.
- Piezas desprendidas, meteoritos, onda y agua usan pools.
- La red envía IDs limitadas, semilla, transformaciones y máscaras compactas.
- Un modo no accede directamente al HUD; usa señales o features inyectadas.
- Un mapa no modifica `GrayboxPlayer`; usa sus métodos públicos.
- Todo modo, mapa, feature o política nueva amplía el smoke test.
- Los recursos referenciados se cargan previamente; no se descargan en ronda.
