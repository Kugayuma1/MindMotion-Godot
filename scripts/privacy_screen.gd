extends Control

@onready var scroll_container = $TextureRect/ScrollContainer
@onready var privacy_text = $TextureRect/ScrollContainer/PrivacyText
@onready var agree_checkbox = $TextureRect/AgreeCheckBox
@onready var back_button = $TextureRect/BackButton

func _ready():
	load_privacy_text()
	# Connect signals if they exist and aren't already connected
	if agree_checkbox and not agree_checkbox.toggled.is_connected(_on_agree_toggled):
		agree_checkbox.toggled.connect(_on_agree_toggled)


func load_privacy_text():
	var privacy_content = """[center][b][font_size=24]Privacy Policy[/font_size][/b][/center]

[b][font_size=18]1. Information We Collect[/font_size][/b]
We collect the following types of information:

[b]Personal Information:[/b]
• Name (first name and last initial)
• Email address (for account management)
• Age (to provide age-appropriate content)
• Gender (for personalized learning experiences)

[b]Educational Data:[/b]
• Learning progress and completion rates
• Time spent on activities
• Performance scores and improvements
• Preferred learning styles

[b]Technical Information:[/b]
• Device type and operating system
• App usage patterns
• Error logs and crash reports (anonymous)

[b][font_size=18]2. How We Use Information[/font_size][/b]
Your information is used to:

• [b]Provide Educational Services:[/b] Deliver personalized learning content
• [b]Track Learning Progress:[/b] Monitor improvement and suggest next steps
• [b]Improve Our Platform:[/b] Enhance features and fix issues
• [b]Communicate Updates:[/b] Send important service notifications
• [b]Ensure Safety:[/b] Protect children and maintain a safe environment
• [b]Research & Development:[/b] Improve educational methodologies (anonymized data only)

[b][font_size=18]3. Information Sharing[/b]
We [b]NEVER[/b]:
• Sell or trade your personal information
• Share data with advertisers
• Use data for commercial marketing to children
• Share individual progress data publicly

We [b]MAY[/b] share information only when:
• Required by law or legal process
• Necessary to protect safety or prevent harm
• With your explicit consent
• With educational institutions (teachers/parents only)

[b][font_size=18]4. Data Security[/font_size][/b]
We implement industry-standard security measures:

• [b]Encryption:[/b] All data transmitted using SSL/TLS encryption
• [b]Access Control:[/b] Limited employee access on need-to-know basis
• [b]Regular Audits:[/b] Periodic security assessments
• [b]Secure Storage:[/b] Data stored in certified secure facilities
• [b]Backup Systems:[/b] Regular backups with encryption
• [b]Incident Response:[/b] Immediate action plan for any security issues

[b][font_size=18]5. Children's Privacy (COPPA Compliance)[/font_size][/b]
We take special care with children's information:

• Minimal data collection for children under 13
• Parental consent required for children under 13
• No behavioral advertising to children
• No public profiles for minors
• Enhanced security for children's accounts
• Regular deletion of unnecessary data

[b]Parents have the right to:[/b]
• Review their child's information
• Request deletion of their child's data
• Refuse further data collection
• Contact us with privacy concerns

[b][font_size=18]6. Cookies and Tracking[/font_size][/b]
We use minimal cookies for:
• Maintaining login sessions
• Remembering user preferences
• Analyzing usage patterns (anonymous)

We [b]DO NOT[/b] use cookies for:
• Cross-site tracking
• Targeted advertising
• Third-party data sharing

[b][font_size=18]7. Data Retention[/font_size][/b]
We retain information:
• [b]Account Data:[/b] Until account deletion
• [b]Educational Progress:[/b] For continued learning (can be deleted on request)
• [b]Technical Logs:[/b] 90 days maximum
• [b]Deleted Accounts:[/b] 30-day recovery period, then permanent deletion

[b][font_size=18]8. Your Rights[/font_size][/b]
You have the right to:
• Access your personal information
• Update or correct your data
• Delete your account and data
• Export your educational progress
• Opt-out of non-essential communications
• File complaints with privacy authorities

[b][font_size=18]9. International Users[/font_size][/b]
For users outside the United States:
• We comply with GDPR (European users)
• Data may be processed in the United States
• We maintain adequate protection standards
• Contact us for region-specific privacy rights

[b][font_size=18]10. Updates to Privacy Policy[/font_size][/b]
We may update this policy to:
• Reflect new features or services
• Comply with legal requirements
• Improve our privacy practices

When we make significant changes:
• Users will be notified via email
• New policy will be posted on our website
• Continued use indicates acceptance

[b][font_size=18]11. Contact Us[/font_size][/b]
For privacy-related questions or concerns:

📧 [b]Email:[/b] privacy@mindmotion.com
📞 [b]Phone:[/b] 1-800-MINDMOTION (ext. 2)
📧 [b]Data Protection Officer:[/b] dpo@mindmotion.com
📮 [b]Mail:[/b] 
MindMotion Privacy Team
123 Education Street
Learning City, LC 12345

[i]Last updated: [current_date][/i]

[center][b]Your privacy and your child's safety are our top priorities.[/b][/center]"""
	
	if privacy_text:
		privacy_text.text = privacy_content.replace("[current_date]", Time.get_datetime_string_from_system())

func _on_agree_toggled(checked: bool):
	# When checkbox is checked, automatically mark as read and return
	if checked:
		if Global.temp_signup_data:
			Global.temp_signup_data["privacy_read"] = true
		# Brief delay so user sees the checkbox get checked
		await get_tree().create_timer(0.5).timeout
		navigate_back_to_signup()
	else:
		# If unchecked, remove the privacy_read flag
		if Global.temp_signup_data:
			Global.temp_signup_data["privacy_read"] = false

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
