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

	# Capture the viewport and resize
	var image: Image = get_viewport().get_texture().get_image()
	image.resize(1024, 1024)
	var png_data: PackedByteArray = image.save_png_to_buffer()
	var body_string: String = png_data.get_string_from_utf8()  # convert to string for HTTPRequest

	# Firebase Storage path (overwrite previous snapshot)
	var file_path = "snapshots/%s/%s.png" % [uid, level_name]
	var upload_url = "https://firebasestorage.googleapis.com/v0/b/%s.appspot.com/o?uploadType=media&name=%s" \
		% [project_id, file_path]

	# Store elapsed time & completed for Firestore save after upload
	var elapsed_time = Time.get_ticks_msec() - Global.start_time
	set_meta("progress_data", {
		"level_name": level_name,
		"timeTaken": elapsed_time,
		"completed": completed,
		"lastPlayedAt": Time.get_datetime_string_from_system()
	})

	# Upload snapshot to Firebase Storage
	var storage_headers = [
		"Authorization: Bearer %s" % id_token,
		"Content-Type: image/png"
	]

	var err = http_request.request(upload_url, storage_headers, HTTPClient.METHOD_POST, body_string)
	if err != OK:
		push_error("❌ Snapshot upload request failed: %s" % err)

# Called when HTTPRequest finishes (both Storage & Firestore)
func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var body_text = body.get_string_from_utf8()

	# Check if Storage upload succeeded
	if response_code == 200:
		var json = JSON.parse_string(body_text)
		if json and json.has("name"):
			var snapshot_url = "https://firebasestorage.googleapis.com/v0/b/mindmotion-55c99.appspot.com/o/%s?alt=media" % json["name"]

			# Prepare Firestore progress data
			var progress_data = get_meta("progress_data")
			progress_data["snapshot"] = snapshot_url
			progress_data["bestTime"] = progress_data["timeTaken"]

			var uid = Global.user_id
			var letter_id = Global.current_letter
			var project_id = "mindmotion-55c99"
			var id_token = Global.firebase_id_token
			var level_name = progress_data["level_name"]

			var url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/users/%s/progress/%s/levels/%s" \
				% [project_id, uid, letter_id, level_name]

			var fields = {}
			for key in progress_data.keys():
				fields[key] = _to_firestore_field(progress_data[key])

			var body_json = {"fields": fields}
			var firestore_headers = [
				"Authorization: Bearer %s" % id_token,
				"Content-Type: application/json"
			]

			var err = http_request.request(url, firestore_headers, HTTPClient.METHOD_PATCH, JSON.stringify(body_json))
			if err != OK:
				push_error("❌ Firestore save request failed: %s" % err)
		else:
			push_error("❌ Snapshot upload response invalid: %s" % body_text)
	else:
		push_error("❌ HTTP request failed %s — %s" % [response_code, body_text])

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
