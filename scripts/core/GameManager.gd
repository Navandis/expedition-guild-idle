extends Node2D

# -----------------------------------------------------------------------------
# GameManager
# -----------------------------------------------------------------------------
# Purpose:
# - Acts as the top-level coordinator for gameplay state in this scene.
# - Godot will call lifecycle functions here at specific times.
#
# Current status:
# - This script is intentionally a scaffold (placeholder) for future systems
#   such as turn flow, encounter setup, saving/loading, etc.
# - We keep the hooks and comments so a new engineer can quickly see where
#   initialization and frame-based logic should live.
# -----------------------------------------------------------------------------

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# _ready() runs once after this node and its children are in the tree.
	# Typical use:
	# - load or reset game/session state
	# - connect signals between managers/UI
	# - spawn initial entities
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# _process() runs every rendered frame.
	# `delta` is the elapsed time (in seconds) since the previous frame.
	# Typical use:
	# - poll non-physics gameplay timers
	# - update UI that depends on time
	# - run lightweight per-frame orchestration
	#
	# For physics-sensitive logic, use _physics_process() instead so updates are
	# deterministic with the physics tick.
	pass
