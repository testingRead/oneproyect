# Reusable weapons and objective modes

## Design rule

Weapon presentation is client-side. The server derives the active weapon from
the authoritative round seed and validates only cooldown, range, hit radius,
damage and current player positions. Clients send an origin and direction, not
damage or hit results.

The models are original low-poly constructions without trademarks or copied
trade dress. Real-world categories are used only as proportion and handling
references:

- **P9:** full-size striker-fired 9 mm pistol proportions. Moderate cadence,
  short-medium range and 34 damage.
- **C16:** compact AR-pattern carbine layout. Fast cadence, longest range and
  24 damage.
- **T12:** tube-fed pump-action shotgun layout. Slow cadence, wide close-range
  hit volume and distance-dependent damage.

All three reuse one input action, RPC, tracer pool, procedural sound bank and
first-person feature.

## Domain

Domain reuses the normal player controller, authorized position relay,
standings and room lifecycle. Each server tick adds one integer objective tick
to active players inside the 6.5-metre central zone. It sends no extra
high-frequency packets. The client renders the zone and estimates local capture
time only for immediate feedback; final placement is calculated by the server.

This pattern can later support multiple control points, moving hills or
team-based capture without changing the movement protocol.
