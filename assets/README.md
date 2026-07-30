# Procedencia de assets

No hay modelos, texturas ni sonidos descargados de terceros en esta etapa.

- `textures/plaza_concrete.webp`: textura de baldosas de plaza azul grisácea,
  generada específicamente para OneProyect y reducida a 512×512 WebP (12 KiB).
- `icon.webp`: icono low-poly de un astronauta cápsula azul esquivando un
  meteorito naranja sobre una plataforma turquesa, generado específicamente
  para OneProyect y reducido a 512×512 WebP (23 KiB).
- `textures/suit_panels.webp`: fuente visible del atlas de traje low-poly,
  reducida a 256×256 WebP (6.8 KiB).
- `textures/suit_panels.res`: copia portable comprimida de 7.1 KiB que usa el
  juego para los cinco colores. Sólo se activa desde calidad Media; el WebP
  fuente queda excluido del APK para no duplicar datos.
- Los cuatro efectos de sonido se sintetizan una sola vez al iniciar mediante
  `scripts/gameplay/sound_bank.gd`; no agregan archivos de audio al APK.

Prompt resumido del icono:

> Icono móvil cuadrado, astronauta cápsula azul low-poly esquivando un meteorito
> naranja, plataforma turquesa, fondo azul marino, formas mínimas, alto
> contraste, sin texto, composición segura para máscaras Android.

Prompt resumido del traje:

> Textura seamless de traje sci-fi low-poly móvil; tela gris neutra, costuras
> azul marino y acentos naranjas; albedo plano sin sombras, texto ni logotipos.
