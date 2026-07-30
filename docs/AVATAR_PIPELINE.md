# Modular avatar pipeline

The visual avatar is independent from gameplay collision and networking. Every
archetype keeps the same logical capsule and damage zones.

## Runtime composition

- One continuous skinned body mesh.
- One shared humanoid skeleton and shared animation names.
- Swappable outfit mesh.
- Species traits (ears and tail) remain part of the skinned archetype.
- Hair or fur tufts use one swappable accessory surface.
- Skin, fur and outfit colors are supplied through material parameters.
- A compact preset ID is sent only when joining a room; visual data never
  enters movement snapshots.

The first archetypes are human male, human female, lynx male and lynx female.
Additional semihuman species reuse this contract instead of adding new player
controllers.

## Blender generation

`tools/blender/generate_avatar_collection.py` builds the four initial bodies as
one metaball volume converted to a continuous decimated mesh. Fitted clothing
is extracted from that surface with a small normal offset, preventing body
clipping without duplicating the body. The script binds at most four bone
influences per vertex, creates reusable animation clips and exports binary glTF
files. GLB is the committed runtime format because the Android Godot editor
cannot invoke Blender to import `.blend` files.

Source `.blend` files are retained outside the Android export and can be
published separately when artistic editing begins.

## Mobile budget

- Four surfaces per visible avatar: body, fitted outfit, face and hair/tuft.
- Four bone influences per vertex.
- Deformation bones only in GLB.
- Backface culling enabled.
- Automatic mesh LOD on Godot import.
- Textures use small shared atlases and Android VRAM compression.
- Five high-quality avatars are measured together before raising detail.
