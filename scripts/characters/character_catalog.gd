class_name CharacterCatalog
extends RefCounted

const GOLDEN_CHARACTER_COST := 5
const GOLDEN_INDEX := 4
const PIONEER_INDEX := 5
const BASIC_MALE_INDEX := 6
const BASIC_FEMALE_INDEX := 7
const NAMES := [
	"HUMANO",
	"HUMANA",
	"LINCE MASCULINO",
	"LINCE FEMENINA",
	"DORADO",
	"PIONERA",
	"BÁSICO HOMBRE",
	"BÁSICA MUJER",
]
const ARCHETYPES := [0, 1, 2, 3, 0, 1, -1, -2]
const COLORS := [
	Color(0.15, 0.58, 0.96),
	Color(0.22, 0.78, 0.5),
	Color(0.75, 0.42, 0.95),
	Color(1.0, 0.48, 0.14),
	Color(1.0, 0.78, 0.2),
	Color(0.9, 0.24, 0.52),
	Color(0.12, 0.48, 0.95),
	Color(0.92, 0.24, 0.58),
]
const SKIN_COLORS := [
	Color(0.52, 0.25, 0.12),
	Color(0.72, 0.40, 0.24),
	Color(0.50, 0.24, 0.08),
	Color(0.72, 0.38, 0.12),
	Color(0.68, 0.40, 0.18),
	Color(0.86, 0.58, 0.38),
	Color(0.12, 0.48, 0.95),
	Color(0.92, 0.24, 0.58),
]
const OUTFIT_COLORS := COLORS


static func sanitize_index(index: int) -> int:
	return clampi(index, 0, NAMES.size() - 1)


static func is_basic(index: int) -> bool:
	var safe_index := sanitize_index(index)
	return safe_index in [BASIC_MALE_INDEX, BASIC_FEMALE_INDEX]
