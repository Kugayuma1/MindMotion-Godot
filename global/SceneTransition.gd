# SceneTransition.gd - Add as AutoLoad
extends CanvasLayer

var fade_rect: ColorRect

func _ready():
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.visible = false
	add_child(fade_rect)

func reload_with_fade():
	fade_rect.visible = true
	fade_rect.modulate.a = 0
	
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.15)
	await tween.finished
	
	get_tree().reload_current_scene()
	
	await get_tree().process_frame
	
	var fade_out = create_tween()
	fade_out.tween_property(fade_rect, "modulate:a", 0.0, 0.15)
	await fade_out.finished
	
	fade_rect.visible = false
