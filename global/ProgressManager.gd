extends Node

@onready var http_request := HTTPRequest.new()

func _ready() -> void:
	add_child(http_request)
	http_request.request_completed.connect(_on_http_request_completed)

# Call this when a game ends
# level_name = "reading", "math", "art", "fine_motor"
# completed = true/false
func save_progress(level_name: String, completed: bool) -> void:
	if not Global.is_logged_in or Global.user_id == "":
		push_error("Cannot save progress: user not logged in")
		return

	var uid = Global.user_id
	var letter_id = Global.current_letter
	var project_id = "mindmotion-55c99"
	var id_token = Global.firebase_id_token

	var elapsed_time = Time.get_ticks_msec() - Global.start_time

	var progress_data = {
		"level_name": level_name,
		"timeTaken": elapsed_time,
		"completed": completed,
		"lastPlayedAt": Time.get_datetime_string_from_system(),
		"bestTime": elapsed_time
	}

	var fields = {}
	for key in progress_data.keys():
		fields[key] = _to_firestore_field(progress_data[key])

	var body_json = {"fields": fields}

	var url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/users/%s/progress/%s/levels/%s" \
		% [project_id, uid, letter_id, level_name]

	var headers = [
		"Authorization: Bearer %s" % id_token,
		"Content-Type: application/json"
	]

	var err = http_request.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body_json))
	if err != OK:
		push_error("❌ Firestore save request failed: %s" % err)


# Called when HTTPRequest finishes (Firestore)
func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var body_text = body.get_string_from_utf8()
	if response_code in [200, 201]:
		print("✅ Progress saved:", body_text)
	else:
		push_error("❌ Firestore save failed %s — %s" % [response_code, body_text])


# Helper to convert values to Firestore format
func _to_firestore_field(value):
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			return {"integerValue": str(value)}
		TYPE_BOOL:
			return {"booleanValue": value}
		TYPE_STRING:
			return {"stringValue": value}
		_:
			return {"stringValue": str(value)}
