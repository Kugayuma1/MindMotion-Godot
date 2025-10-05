extends Node

# Student data management singleton
# Add this as an autoload: StudentData

var current_student_id: String = ""
var student_cognitive_data: Dictionary = {}
var student_motion_data: Dictionary = {}
var student_voice_data: Dictionary = {}

# HTTP request nodes
var cognitive_http_request: HTTPRequest
var motion_http_request: HTTPRequest
var letter_progress_http_request: HTTPRequest
var voice_http_request: HTTPRequest

# Signals
signal cognitive_data_loaded(data: Dictionary)
signal motion_data_loaded(data: Dictionary) 
signal letter_progress_loaded(letter: String, data: Dictionary)
signal voice_data_loaded(data: Dictionary)

func _ready():
	# Initialize HTTP requests
	cognitive_http_request = HTTPRequest.new()
	add_child(cognitive_http_request)
	cognitive_http_request.request_completed.connect(_on_cognitive_data_completed)
	
	motion_http_request = HTTPRequest.new()
	add_child(motion_http_request)
	motion_http_request.request_completed.connect(_on_motion_data_completed)
	
	letter_progress_http_request = HTTPRequest.new()
	add_child(letter_progress_http_request)
	letter_progress_http_request.request_completed.connect(_on_letter_progress_completed)
	
	voice_http_request = HTTPRequest.new()
	add_child(voice_http_request)
	voice_http_request.request_completed.connect(_on_voice_data_completed)

# Set which student we're viewing
func set_current_student(student_id: String):
	if current_student_id != student_id:
		current_student_id = student_id
		student_cognitive_data.clear()
		student_motion_data.clear()
		student_voice_data.clear()
	else:
		current_student_id = student_id

# Load cognitive activities data (letter progress)
func load_student_cognitive_data():
	if current_student_id.is_empty():
		print("ERROR: No student ID set")
		return false
	
	print("DEBUG: Loading cognitive data for student: %s" % current_student_id)
	var url = "https://firestore.googleapis.com/v1/projects/mindmotion-55c99/databases/(default)/documents/users/%s/progress" % current_student_id
	print("DEBUG: Request URL: %s" % url)
	
	var success = Global.make_authenticated_request(cognitive_http_request, url, HTTPClient.METHOD_GET)
	print("DEBUG: Request initiated: %s" % success)
	return success

# Load specific letter progress with levels
func load_letter_progress(letter: String):
	if current_student_id.is_empty():
		return false
	
	var url = "https://firestore.googleapis.com/v1/projects/mindmotion-55c99/databases/(default)/documents/users/%s/progress/%s/levels" % [current_student_id, letter]
	return Global.make_authenticated_request(letter_progress_http_request, url, HTTPClient.METHOD_GET)

# Load motion activities data
func load_student_motion_data():
	if current_student_id.is_empty():
		return false
	
	var url = "https://firestore.googleapis.com/v1/projects/mindmotion-55c99/databases/(default)/documents/users/%s/activities" % current_student_id
	return Global.make_authenticated_request(motion_http_request, url, HTTPClient.METHOD_GET)

# Load voice activities data
func load_student_voice_data():
	if current_student_id.is_empty():
		print("ERROR: No student ID set for voice data")
		return false
	
	print("DEBUG: Loading voice data for student: %s" % current_student_id)
	var url = "https://firestore.googleapis.com/v1/projects/mindmotion-55c99/databases/(default)/documents/users/%s/voice_data" % current_student_id
	print("DEBUG: Voice request URL: %s" % url)
	
	var success = Global.make_authenticated_request(voice_http_request, url, HTTPClient.METHOD_GET)
	print("DEBUG: Voice request initiated: %s" % success)
	return success

# Process cognitive data response
func _on_cognitive_data_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var response_text = body.get_string_from_utf8()
	
	print("DEBUG: HTTP Request completed")
	print("DEBUG: Result code: %d" % result)
	print("DEBUG: Response code: %d" % response_code)
	print("DEBUG: Response body length: %d" % response_text.length())
	
	if response_code == 200:
		print("DEBUG: Parsing JSON response...")
		var json = JSON.new()
		if json.parse(response_text) == OK:
			print("DEBUG: JSON parsed successfully")
			process_cognitive_data(json.data)
		else:
			print("DEBUG: JSON parsing failed")
			student_cognitive_data = {}
			cognitive_data_loaded.emit(student_cognitive_data)
	elif response_code == 401:
		print("DEBUG: Authentication failed, refreshing token...")
		# Token refresh logic would go here
	else:
		print("DEBUG: HTTP request failed with code: %d" % response_code)
		print("DEBUG: Response body: %s" % response_text)
		student_cognitive_data = {}
		cognitive_data_loaded.emit(student_cognitive_data)

# Process letter progress response
func _on_letter_progress_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var response_text = body.get_string_from_utf8()
	
	if response_code == 200:
		var json = JSON.new()
		if json.parse(response_text) == OK:
			# Extract letter from the request URL if needed
			# For now, we'll emit with the data and let the scene handle it
			letter_progress_loaded.emit("", json.data)
	else:
		letter_progress_loaded.emit("", {})

# Process motion data response  
func _on_motion_data_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var response_text = body.get_string_from_utf8()
	
	if response_code == 200:
		var json = JSON.new()
		if json.parse(response_text) == OK:
			process_motion_data(json.data)
		else:
			student_motion_data = {}
			motion_data_loaded.emit(student_motion_data)
	else:
		student_motion_data = {}
		motion_data_loaded.emit(student_motion_data)

# Process voice data response
func _on_voice_data_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var response_text = body.get_string_from_utf8()
	
	print("DEBUG: Voice HTTP Request completed")
	print("DEBUG: Voice Result code: %d" % result)
	print("DEBUG: Voice Response code: %d" % response_code)
	
	if response_code == 200:
		print("DEBUG: Parsing voice JSON response...")
		var json = JSON.new()
		if json.parse(response_text) == OK:
			print("DEBUG: Voice JSON parsed successfully")
			process_voice_data(json.data)
		else:
			print("DEBUG: Voice JSON parsing failed")
			student_voice_data = {}
			voice_data_loaded.emit(student_voice_data)
	elif response_code == 401:
		print("DEBUG: Voice auth failed, refreshing token...")
	else:
		print("DEBUG: Voice HTTP request failed with code: %d" % response_code)
		print("DEBUG: Voice Response body: %s" % response_text)
		student_voice_data = {}
		voice_data_loaded.emit(student_voice_data)

# Process cognitive data from Firebase
func process_cognitive_data(data: Dictionary):
	student_cognitive_data.clear()
	
	print("DEBUG: Processing cognitive data: %s" % var_to_str(data))
	
	if data.has("documents"):
		print("DEBUG: Found %d documents" % data.documents.size())
		for doc in data.documents:
			var letter = doc.name.split("/")[-1]  # Extract letter from document path
			var doc_data = extract_document_fields(doc)
			print("DEBUG: Letter %s data: %s" % [letter, var_to_str(doc_data)])
			student_cognitive_data[letter] = doc_data
	else:
		print("DEBUG: No documents found in response")
	
	print("DEBUG: Final cognitive data: %s" % var_to_str(student_cognitive_data))
	cognitive_data_loaded.emit(student_cognitive_data)

# Process motion data from Firebase
func process_motion_data(data: Dictionary):
	student_motion_data.clear()
	
	if data.has("documents"):
		for doc in data.documents:
			var activity_id = doc.name.split("/")[-1]  # Extract activity ID
			var doc_data = extract_document_fields(doc)
			
			# Group by activity type
			var activity_type = doc_data.get("activityType", "unknown")
			if not student_motion_data.has(activity_type):
				student_motion_data[activity_type] = []
			
			student_motion_data[activity_type].append({
				"id": activity_id,
				"success": doc_data.get("success", false),
				"timestamp": doc_data.get("timestamp", 0),
				"date": doc_data.get("date", "")
			})
	
	# Sort activities by timestamp (newest first)
	for activity_type in student_motion_data.keys():
		student_motion_data[activity_type].sort_custom(func(a, b): return a.timestamp > b.timestamp)
	
	motion_data_loaded.emit(student_motion_data)

# Process voice data from Firebase
func process_voice_data(data: Dictionary):
	student_voice_data.clear()
	
	print("DEBUG: Processing voice data: %s" % var_to_str(data))
	
	if data.has("documents"):
		print("DEBUG: Found %d voice documents" % data.documents.size())
		for doc in data.documents:
			var voice_id = doc.name.split("/")[-1]  # Extract voice ID
			var doc_data = extract_document_fields(doc)
			print("DEBUG: Voice ID %s data: %s" % [voice_id, var_to_str(doc_data)])
			
			# Group by date
			var date = doc_data.get("date", "Unknown")
			if not student_voice_data.has(date):
				student_voice_data[date] = []
			
			student_voice_data[date].append({
				"voice_id": voice_id,
				"word": doc_data.get("word", ""),
				"timestamp": doc_data.get("timestamp", 0),
				"date": date
			})
	else:
		print("DEBUG: No voice documents found in response")
	
	# Sort each date's words by timestamp (newest first)
	for date in student_voice_data.keys():
		student_voice_data[date].sort_custom(func(a, b): return a.timestamp > b.timestamp)
	
	print("DEBUG: Final voice data: %s" % var_to_str(student_voice_data))
	voice_data_loaded.emit(student_voice_data)

# Extract fields from Firebase document
func extract_document_fields(doc: Dictionary) -> Dictionary:
	var result = {}
	
	if doc.has("fields"):
		var fields = doc.fields
		
		for field_name in fields.keys():
			var field_data = fields[field_name]
			
			# Extract value based on type
			if field_data.has("stringValue"):
				result[field_name] = field_data.stringValue
			elif field_data.has("integerValue"):
				result[field_name] = int(field_data.integerValue)
			elif field_data.has("booleanValue"):
				result[field_name] = field_data.booleanValue
			elif field_data.has("doubleValue"):
				result[field_name] = float(field_data.doubleValue)
			elif field_data.has("timestampValue"):
				result[field_name] = field_data.timestampValue
			
			# Debug: Print each field extraction
			print("DEBUG: Field %s -> %s" % [field_name, str(result.get(field_name, "FAILED"))])
	
	return result

# Utility functions for rating calculations
func get_cognitive_rating(average_time_ms: float) -> String:
	# Convert milliseconds to seconds
	var average_time_seconds = average_time_ms / 1000.0
	
	if average_time_seconds <= 3.0:
		return "Very Good"
	elif average_time_seconds <= 6.0:
		return "Good"
	elif average_time_seconds <= 9.0:
		return "Average"
	elif average_time_seconds <= 12.0:
		return "Low"
	else:
		return "Very Low"

func get_motion_success_rate(activity_type: String) -> float:
	if not student_motion_data.has(activity_type):
		return 0.0
	
	var activities = student_motion_data[activity_type]
	if activities.size() == 0:
		return 0.0
	
	var successful = 0
	for activity in activities:
		if activity.success:
			successful += 1
	
	return (float(successful) / float(activities.size())) * 100.0

func get_motion_attempt_count(activity_type: String) -> int:
	if not student_motion_data.has(activity_type):
		return 0
	return student_motion_data[activity_type].size()

# Get current student data
func get_current_student_cognitive_data() -> Dictionary:
	return student_cognitive_data.duplicate()

func get_current_student_motion_data() -> Dictionary:
	return student_motion_data.duplicate()

func get_current_student_voice_data() -> Dictionary:
	return student_voice_data.duplicate()
