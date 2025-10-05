extends Control

@onready var pieces = [$piece1, $piece2, $piece3, $piece4]

func _ready():
	# Each piece can ONLY snap to its correct marker
	$piece1.target_marker_path = NodePath("Marker2D")    # piece1 → Marker2D
	$piece2.target_marker_path = NodePath("Marker2D2")   # piece2 → Marker2D2  
	$piece3.target_marker_path = NodePath("Marker2D3")   # piece3 → Marker2D3
	$piece4.target_marker_path = NodePath("Marker2D4")   # piece4 → Marker2D4

func check_completion():
	var placed_count = 0
	for piece in pieces:
		if piece.is_placed:
			placed_count += 1
	
	if placed_count == pieces.size():
		print("Puzzle Complete! All pieces in correct places!")
