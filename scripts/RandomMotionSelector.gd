class_name RandomMotionSelector
extends RefCounted

# Motion activity configurations
const MOTION_ACTIVITIES = {
	"clap": {
		"scene_path": "res://scenes/Clap.tscn",
		"display_name": "Clapping",
		"description": "Clap your hands together"
	},
	"wave": {
		"scene_path": "res://scenes/Wave.tscn", 
		"display_name": "Waving",
		"description": "Wave both hands"
	}
}

# Static method to select random motion activity
static func get_random_motion_activity() -> Dictionary:
	var activity_keys = MOTION_ACTIVITIES.keys()
	var random_key = activity_keys[randi() % activity_keys.size()]
	
	var selected_activity = MOTION_ACTIVITIES[random_key].duplicate()
	selected_activity["type"] = random_key
	
	print("Selected random motion activity: ", selected_activity.display_name)
	return selected_activity

# Static method to get random scene path (you handle the scene loading)
static func get_random_motion_scene_path() -> String:
	var selected_activity = get_random_motion_activity()
	return selected_activity.scene_path

# Method to get all available activities (for UI display)
static func get_all_activities() -> Dictionary:
	return MOTION_ACTIVITIES

# Method to check if an activity type is valid
static func is_valid_activity(activity_type: String) -> bool:
	return MOTION_ACTIVITIES.has(activity_type)

# Method to get activity info by type
static func get_activity_info(activity_type: String) -> Dictionary:
	if is_valid_activity(activity_type):
		var info = MOTION_ACTIVITIES[activity_type].duplicate()
		info["type"] = activity_type
		return info
	else:
		push_error("Invalid activity type: " + activity_type)
		return {}

# Method for weighted random selection (if you want some activities more common)
static func get_weighted_random_activity(weights: Dictionary = {}) -> Dictionary:
	# Default equal weights if none provided
	if weights.is_empty():
		weights = {"clap": 1.0, "wave": 1.0}
	
	var total_weight = 0.0
	for weight in weights.values():
		total_weight += weight
	
	var random_value = randf() * total_weight
	var current_weight = 0.0
	
	for activity_type in weights.keys():
		current_weight += weights[activity_type]
		if random_value <= current_weight and MOTION_ACTIVITIES.has(activity_type):
			var selected_activity = MOTION_ACTIVITIES[activity_type].duplicate()
			selected_activity["type"] = activity_type
			print("Selected weighted motion activity: ", selected_activity.display_name)
			return selected_activity
	
	# Fallback to regular random selection
	return get_random_motion_activity()
