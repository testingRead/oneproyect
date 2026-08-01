# Hito interno: base antes de UX

La rama `feature/local-minigame` queda consolidada en este punto como base para
interfaz y presentación. Las siguientes decisiones se consideran estables hasta
que una prueba real revele un fallo:

- Godot 4.7.1, Compatibility/OpenGL y APK Android ARM64 local.
- Sala local y LAN como entrada principal a los minijuegos nuevos.
- Una isla física común y mapas de ronda montados dinámicamente.
- Un cuerpo base, controles táctiles y cámara por perfil de minijuego.
- Física nativa para objetos interactivos; no se duplican simulaciones visuales.
- LAN ligero con ENet: posiciones/objetos frecuentes no confiables y eventos
  visibles confiables.
- Puntos temporales sólo durante la vida de la sala.

Antes de cambiar UX, un cambio debe respetar estas comprobaciones:

1. iniciar local sin servidor;
2. crear y unirse a una sala LAN;
3. completar una ronda y volver a esa sala;
4. limpiar mapa, objetos y bots;
5. mantener el marcador temporal de sala;
6. compilar ARM64 en Termux y ejecutar la batería de pruebas.

La siguiente etapa puede cambiar jerarquía visual, pantallas, textos y flujo de
selección, pero no debe duplicar controladores, hosts de minijuego o estado de
sala. La interfaz debe consultar esos sistemas ya existentes.
