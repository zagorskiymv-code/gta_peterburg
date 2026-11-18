extends Resource

const Step = preload("res://scripts/systems/mission_step.gd")

@export var id := ""
@export var title := ""
@export var briefing := ""
@export var reward_rubles := 0
@export var unlocks_chapter := 0
@export var unlocks_story_chapter := 0
@export var steps: Array[Step] = []
