# Contenido modular local

El menú descubre recursos `.tres` sin listas manuales.

- Personajes: `res://data/characters/` o `res://content/characters/`.
- Minijuegos: `res://data/minigames/` o `res://content/minigames/`.

Cada personaje declara su `character_scene`. Cada minijuego declara un
`map_definition`. Al añadir una definición válida al directorio, aparece en la
sala al siguiente inicio. Las escenas pueden mantener sus animaciones y
recursos junto a su propia carpeta; el menú no necesita modificarse.
