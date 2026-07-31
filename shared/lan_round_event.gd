class_name LanRoundEvent
extends RefCounted

enum Kind {
	HOLDER_CHANGED = 1,
	SCORE_CHANGED = 2,
	ROUND_COMPLETED = 3,
	HAZARD_STATE = 4,
}

enum Subject {
	CROWN = 1,
	BOMB = 2,
	FOOTBALL = 3,
	BATEBALL = 4,
	TORNADO = 5,
}
