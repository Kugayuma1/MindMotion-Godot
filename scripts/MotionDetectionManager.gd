class_name MotionDetectionManager
extends Node

const FIREBASE_PROJECT_ID = "mindmotion-55c99"
const FIRESTORE_URL = "https://firestore.googleapis.com/v1/projects/" + FIREBASE_PROJECT_ID + "/databases/(default)/documents/"

var http_request: HTTPRequest
var current_session_id: String = ""
var is_waiting_for_motion: bool = false
var poll_timer: Timer
var max_poll_attempts: int = 20
var poll_attempts: int = 0
var session_creation_pending: bool = false

signal motion_detected
signal motion_timeout
signal motion_session_started(motion_type: String)

func _ready():
	setup_http_request()

func setup_http_request():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	http_request.timeout = 10.0

func start_motion_detection(motion_type: String, student_id: String):
	if is_waiting_for_motion:
		print("Already waiting for motion detection")
		return
	
	if motion_type == "" or student_id == "":
		push_error("Invalid motion_type or student_id")
		emit_signal("motion_timeout")
		return
	
	if not Global or Global.firebase_id_token == "" or Global.firebase_id_token == null:
		push_error("Firebase authentication token missing")
		emit_signal("motion_timeout")
		return
	
	current_session_id = generate_session_id()
	poll_attempts = 0
	session_creation_pending = true
	
	print("Creating motion session: ", current_session_id)
	
	var session_data = {
		"fields": {
			"status": {
				"stringValue": "waiting"
			},
			"motionType": {
				"stringValue": motion_type
			},
			"detected": {
				"booleanValue": false
			},
			"studentId": {
				"stringValue": student_id
			},
			"timestamp": {
				"integerValue": str(int(Time.get_unix_time_from_system()))
			},
			"timeoutSeconds": {
				"integerValue": "60"
			}
		}
	}
	
	var url = FIRESTORE_URL + "motion_sessions/" + current_session_id
	var json_data = JSON.stringify(session_data)
	
	print("Session URL: ", url)
	print("Session data: ", json_data)
	
	var headers = [
		"Authorization: Bearer " + Global.firebase_id_token,
		"Content-Type: application/json"
	]
	
	var result = http_request.request(url, headers, HTTPClient.METHOD_PATCH, json_data)
	if result != OK:
		push_error("Failed to create HTTP request: " + str(result))
		emit_signal("motion_timeout")
		session_creation_pending = false
		return

func start_polling():
	if poll_timer:
		poll_timer.queue_free()
	
	poll_timer = Timer.new()
	add_child(poll_timer)
	poll_timer.wait_time = 3.0
	poll_timer.timeout.connect(_poll_session_status)
	poll_timer.start()
	
	_poll_session_status()

func _poll_session_status():
	if not is_waiting_for_motion or current_session_id == "":
		return
	
	poll_attempts += 1
	print("Polling session status (attempt ", poll_attempts, "/", max_poll_attempts, ")")
	
	if poll_attempts > max_poll_attempts:
		print("Maximum polling attempts reached - timing out")
		_motion_completed(false)
		return
	
	var url = FIRESTORE_URL + "motion_sessions/" + current_session_id
	var headers = ["Authorization: Bearer " + Global.firebase_id_token]
	
	var result = http_request.request(url, headers, HTTPClient.METHOD_GET)
	if result != OK:
		push_error("Failed to poll session: " + str(result))
		return

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var json_text = body.get_string_from_utf8()
	print("Firestore response - Code: ", response_code)
	
	if response_code != 200:
		print("Error response body: ", json_text)
	
	if response_code == 200:
		# FIXED: Check if this was session creation
		if session_creation_pending:
			session_creation_pending = false
			print("✅ Session created successfully!")
			is_waiting_for_motion = true
			emit_signal("motion_session_started", "clapping")
			start_polling()
		elif is_waiting_for_motion and poll_attempts > 0:
			# This is polling response
			var json = JSON.new()
			var parse_result = json.parse(json_text)
			
			if parse_result == OK:
				var data = json.data
				if data.has("fields"):
					var fields = data.fields
					
					if fields.has("detected") and fields.detected.has("booleanValue"):
						if fields.detected.booleanValue == true:
							print("Motion detected in Firestore!")
							_motion_completed(true)
							return
					
					if fields.has("status") and fields.status.has("stringValue"):
						var status = fields.status.stringValue
						if status == "timeout":
							print("Session marked as timeout in Firestore")
							_motion_completed(false)
							return
						elif status == "completed":
							print("Session marked as completed in Firestore")
							_motion_completed(true)
							return
	elif response_code == 404:
		if is_waiting_for_motion:
			print("Session not found (may have been deleted)")
			_motion_completed(false)
	else:
		# Handle creation errors
		if session_creation_pending:
			session_creation_pending = false
			if response_code == 400:
				push_error("Bad request creating session. Check authentication and data format.")
				push_error("Response: " + json_text)
			elif response_code == 401:
				push_error("Unauthorized. Check Firebase token.")
			elif response_code == 403:
				push_error("Forbidden. Check Firestore rules.")
			emit_signal("motion_timeout")

func _motion_completed(success: bool):
	if not is_waiting_for_motion:
		return
	
	print("Motion detection completed. Success: ", success)
	is_waiting_for_motion = false
	session_creation_pending = false
	
	if poll_timer and is_instance_valid(poll_timer):
		poll_timer.stop()
		poll_timer.queue_free()
		poll_timer = null
	
	if current_session_id != "":
		cleanup_session_async()
	
	current_session_id = ""
	poll_attempts = 0
	
	if success:
		emit_signal("motion_detected")
	else:
		emit_signal("motion_timeout")

func cleanup_session_async():
	var url = FIRESTORE_URL + "motion_sessions/" + current_session_id
	var headers = ["Authorization: Bearer " + Global.firebase_id_token]
	
	var cleanup_request = HTTPRequest.new()
	add_child(cleanup_request)
	
	var result = cleanup_request.request(url, headers, HTTPClient.METHOD_DELETE)
	if result == OK:
		print("Session cleanup initiated for: ", current_session_id)
	
	await get_tree().create_timer(2.0).timeout
	if cleanup_request and is_instance_valid(cleanup_request):
		cleanup_request.queue_free()

func cleanup_session():
	is_waiting_for_motion = false
	current_session_id = ""
	poll_attempts = 0
	session_creation_pending = false
	
	if poll_timer and is_instance_valid(poll_timer):
		poll_timer.stop()
		poll_timer.queue_free()
		poll_timer = null
	
	print("Motion detection manager cleaned up")

func save_activity_to_firestore(activity_data: Dictionary):
	print("Saving student activity to Firestore...")
	
	if not activity_data.has("student_id") or activity_data.student_id == "":
		push_error("Cannot save activity - missing student_id")
		return
	
	if not Global or Global.firebase_id_token == "":
		push_error("Cannot save activity - missing Firebase token")
		return
	
	var student_id = activity_data.student_id
	var activity_id = "clapping_" + str(int(Time.get_unix_time_from_system()))
	
	var firestore_data = {
		"fields": {
			"activityType": {
				"stringValue": str(activity_data.get("activity_type", "clapping"))
			},
			"success": {
				"booleanValue": bool(activity_data.get("success", false))
			},
			"timestamp": {
				"integerValue": str(int(activity_data.get("timestamp", Time.get_unix_time_from_system())))
			},
			"date": {
				"stringValue": str(activity_data.get("date", Time.get_datetime_string_from_system()))
			},
			"studentName": {
				"stringValue": str(activity_data.get("student_name", "Unknown"))
			},
			"level": {
				"stringValue": str(activity_data.get("level", "unknown"))
			}
		}
	}
	
	var url = FIRESTORE_URL + "users/" + student_id + "/activities/" + activity_id
	var json_data = JSON.stringify(firestore_data)
	var headers = [
		"Authorization: Bearer " + Global.firebase_id_token,
		"Content-Type: application/json"
	]
	
	var activity_request = HTTPRequest.new()
	add_child(activity_request)
	activity_request.request_completed.connect(_on_activity_save_completed)
	
	var result = activity_request.request(url, headers, HTTPClient.METHOD_PATCH, json_data)
	if result == OK:
		print("Activity save request sent for student: ", student_id)
	else:
		push_error("Failed to send activity save request: " + str(result))

func _on_activity_save_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if response_code == 200:
		print("✅ Activity successfully saved to Firestore")
	else:
		push_error("❌ Failed to save activity. Response code: " + str(response_code))
		print("Response body: ", body.get_string_from_utf8())

func generate_session_id() -> String:
	var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var session_id = ""
	for i in range(12):
		session_id += chars[randi() % chars.length()]
	return "session_" + session_id + "_" + str(int(Time.get_unix_time_from_system()))
