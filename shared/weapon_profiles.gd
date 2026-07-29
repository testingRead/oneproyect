class_name WeaponProfiles
extends RefCounted

enum Id { P9, C16, T12 }

const COUNT := 3


static func from_round_seed(round_seed: int) -> int:
	return posmod(round_seed, COUNT)


static func display_name(weapon_id: int) -> String:
	match weapon_id:
		Id.C16:
			return "C16 · CARABINA"
		Id.T12:
			return "T12 · CORREDERA"
		_:
			return "P9 · PISTOLA"


static func reference_name(weapon_id: int) -> String:
	match weapon_id:
		Id.C16:
			return "DISEÑO TIPO AR"
		Id.T12:
			return "TUBULAR DE CORREDERA"
		_:
			return "STRIKER 9 MM"


static func cooldown_ticks(weapon_id: int) -> int:
	match weapon_id:
		Id.C16:
			return 4
		Id.T12:
			return 15
		_:
			return 6


static func cooldown_seconds(weapon_id: int) -> float:
	return float(cooldown_ticks(weapon_id)) / 20.0


static func maximum_range(weapon_id: int) -> float:
	match weapon_id:
		Id.C16:
			return 36.0
		Id.T12:
			return 18.0
		_:
			return 27.0


static func hit_radius_squared(weapon_id: int) -> float:
	match weapon_id:
		Id.T12:
			return 1.75
		Id.C16:
			return 0.62
		_:
			return 0.78


static func damage(weapon_id: int, distance: float) -> int:
	match weapon_id:
		Id.C16:
			return 24
		Id.T12:
			return 48 if distance <= 8.0 else 30
		_:
			return 34
