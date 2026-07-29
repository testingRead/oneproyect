class_name CharacterCatalog
extends RefCounted

const GOLDEN_CHARACTER_COST := 5
const NAMES := [
	"EXPLORADOR",
	"GUARDABOSQUES",
	"LINCE",
	"TÉCNICO",
	"DORADO",
]
const COLORS := [
	Color(0.15, 0.58, 0.96),
	Color(0.22, 0.78, 0.5),
	Color(0.75, 0.42, 0.95),
	Color(1.0, 0.48, 0.14),
	Color(1.0, 0.78, 0.2),
]


static func sanitize_index(index: int) -> int:
	return clampi(index, 0, NAMES.size() - 1)
