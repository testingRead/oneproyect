# Scalable procedural character rig

The logical collision body and seven synchronized damage zones remain identical
for every character. Visual anatomy is layered on top and never changes network
packet size or authoritative collision rules.

## Quality layers

- **Low:** original head, torso and complete limbs. Basic walk, jump, push, aim
  and reduced reload movement.
- **Medium:** adds chest, pelvis, forearms and feet using box geometry, plus
  shoulder and reload motion.
- **High:** replaces primary and secondary shapes with rounded sphere/capsule
  geometry and adds torso/head secondary recoil.

Secondary parts follow their parent synchronized limb and disappear with it.
They do not create extra hitboxes or desmemberment bits.

## Anatomies

`PIONERA` is an independent sixth anatomy with narrower shoulders, a distinct
chest/pelvis ratio, adjusted arm spacing and leg proportions. It uses the same
animation and equipment APIs as every other character.

## Combat animation

The local shooter exposes magazine ammunition, manual or automatic reload,
first-person recoil and per-weapon timing. Remote clients infer aiming,
shooting, weapon model and reload from the already reliable shot events. The
server independently enforces magazine size and reload duration.
