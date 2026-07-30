class_name CharacterCatalog
extends RefCounted

const GOLDEN_CHARACTER_COST := 5
const GOLDEN_INDEX := 4
const PIONEER_INDEX := 5
const NAMES := [
	"HUMANO",
	"HUMANA",
	"LINCE MASCULINO",
	"LINCE FEMENINA",
	"DORADO",
	"PIONERA",
]
const ARCHETYPES := [0, 1, 2, 3, 0, 1]
const COLORS := [
	Color(0.15, 0.58, 0.96),
	Color(0.22, 0.78, 0.5),
	Color(0.75, 0.42, 0.95),
	Color(1.0, 0.48, 0.14),
	Color(1.0, 0.78, 0.2),
	Color(0.9, 0.24, 0.52),
]
const SKIN_COLORS := [
	Color(0.52, 0.25, 0.12),
	Color(0.72, 0.40, 0.24),
	Color(0.50, 0.24, 0.08),
	Color(0.72, 0.38, 0.12),
	Color(0.68, 0.40, 0.18),
	Color(0.86, 0.58, 0.38),
]
const OUTFIT_COLORS := COLORS


static func sanitize_index(index: int) -> int:
	return clampi(index, 0, NAMES.size() - 1)
