extends Control

@onready var scroll_container = $TextureRect/ScrollContainer
@onready var terms_text = $TextureRect/ScrollContainer/TermsText
@onready var agree_checkbox = $TextureRect/AgreeCheckBox
@onready var back_button = $TextureRect/BackButton

func _ready():
	load_terms_text()
	# Connect signals if they exist and aren't already connected
	if agree_checkbox and not agree_checkbox.toggled.is_connected(_on_agree_toggled):
		agree_checkbox.toggled.connect(_on_agree_toggled)

func load_terms_text():
	var terms_content = """[center][b][font_size=24]Terms & Conditions[/font_size][/b][/center]

[b][font_size=18]1. Acceptance of Terms[/font_size][/b]
By using MindMotion, you agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use our service.

[b][font_size=18]2. Use of Service[/font_size][/b]
This educational platform is designed for children aged 3-18 to improve their learning skills through interactive activities including:
• Reading comprehension exercises
• Fine motor skill development
• Mathematical problem solving
• Creative art activities

[b][font_size=18]3. User Accounts[/font_size][/b]
You are responsible for:
• Maintaining the confidentiality of your account information
• All activities that occur under your account
• Ensuring accurate information is provided during registration
• Notifying us immediately of any unauthorized use

[b][font_size=18]4. Content and Conduct[/font_size][/b]
Users must not:
• Upload harmful, offensive, or inappropriate content
• Share personal information of minors publicly
• Attempt to hack or disrupt the service
• Use the platform for any illegal activities

All activities should be educational and appropriate for children.

[b][font_size=18]5. Privacy[/font_size][/b]
We are committed to protecting user privacy, especially for minors. We:
• Collect minimal necessary information
• Never share personal data with third parties
• Implement strong security measures
• Comply with COPPA regulations

Please review our Privacy Policy for detailed information.

[b][font_size=18]6. Educational Content[/font_size][/b]
Our educational content is designed by certified educators and child development specialists. While we strive for accuracy:
• Content is for educational purposes only
• Results may vary between individual children
• We recommend parental supervision for younger users
• Professional educational assessment should supplement our tools

[b][font_size=18]7. Modifications[/font_size][/b]
We reserve the right to modify these terms at any time. When we do:
• Users will be notified of significant changes
• Continued use constitutes acceptance of modified terms
• You may discontinue use if you disagree with changes

[b][font_size=18]8. Limitation of Liability[/font_size][/b]
MindMotion is provided "as is" without warranties of any kind. We are not liable for:
• Any damages arising from the use of this service
• Technical issues or service interruptions
• Loss of user data (though we implement backup systems)
• Educational outcomes or learning results

[b][font_size=18]9. Termination[/font_size][/b]
We may terminate accounts that:
• Violate these terms of service
• Engage in harmful behavior
• Provide false information
• Remain inactive for extended periods

[b][font_size=18]10. Contact Information[/font_size][/b]
For questions about these terms, please contact us at:
📧 Email: support@mindmotion.com
📞 Phone: 1-800-MINDMOTION
🌐 Website: www.mindmotion.com

[i]Last updated: [current_date][/i]

[center][b]Thank you for choosing MindMotion for your child's educational journey![/b][/center]"""
	
	if terms_text:
		terms_text.text = terms_content.replace("[current_date]", Time.get_datetime_string_from_system())

func _on_agree_toggled(checked: bool):
	# When checkbox is checked, automatically mark as read and return
	if checked:
		if Global.temp_signup_data:
			Global.temp_signup_data["terms_read"] = true
		# Brief delay so user sees the checkbox get checked
		navigate_back_to_signup()
	else:
		# If unchecked, remove the terms_read flag
		if Global.temp_signup_data:
			Global.temp_signup_data["terms_read"] = false

func navigate_back_to_signup():
	# Determine which signup screen to return to
	var return_scene = "res://scenes/StudentSignup.tscn"  # default
	
	if Global.temp_signup_data and Global.temp_signup_data.has("return_scene"):
		var scene_name = Global.temp_signup_data["return_scene"]
		if scene_name == "teacher_signup":
			return_scene = "res://scenes/TeacherSignup.tscn"
		elif scene_name == "student_signup":
			return_scene = "res://scenes/StudentSignup.tscn"
	
	get_tree().change_scene_to_file(return_scene)
	
func _on_back_button_pressed():
	# Return to signup without confirming
	navigate_back_to_signup()
