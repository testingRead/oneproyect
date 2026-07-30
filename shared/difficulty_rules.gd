class_name DifficultyRules
extends RefCounted

const WEAPON_PROFILE_COUNT := 3

enum Level {
	EASY,
	NORMAL,
	HARD,
}


static func from_round_seed(round_seed: int) -> int:
	# Weapon selection uses the lowest seed trit. Dividing first keeps both
	# deterministic selections independent without adding network payload.
	return posmod(round_seed / WEAPON_PROFILE_COUNT, Level.size())


static func display_name(level: int) -> String:
	match level:
		Level.EASY:
			return "SUAVE"
		Level.HARD:
			return "INTENSA"
		_:
			return "NORMAL"


static func intensity(level: int) -> float:
	match level:
		Level.EASY:
			return 0.82
		Level.HARD:
			return 1.28
		_:
			return 1.0
