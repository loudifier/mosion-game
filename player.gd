extends "res://circle.gd"

@export var outline = 6.0

@export var move_speed = 10
@export var friction = 0.01

signal game_over

signal add_score

# Called when the node enters the scene tree for the first time.
func _ready():
	super._ready()
	growth_factor = 0.2


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	super._process(delta)
	
	# wrap around edge of screen
	var screen_size = get_viewport_rect().size
	position = Vector2(fmod(position.x+screen_size.x,screen_size.x), fmod(position.y+screen_size.y,screen_size.y))
	
	# translate user input into player movement
	var accel = Vector2.ZERO
	
	# WASD added to built-in up/down/left/right actions
	if Input.is_action_pressed("ui_up"):
		accel += Vector2.UP
	if Input.is_action_pressed("ui_down"):
		accel += Vector2.DOWN
	if Input.is_action_pressed("ui_left"):
		accel += Vector2.LEFT
	if Input.is_action_pressed("ui_right"):
		accel += Vector2.RIGHT
	
	if accel.length() > 0:
		accel = accel.normalized() * move_speed
		
	velocity += accel - velocity * friction
	

func set_radius(new_radius):
	if new_radius > radius and get_node("/root/Main").play_state == get_node("/root/Main").states.PLAY:
		add_score.emit(new_radius - radius)
	super.set_radius(new_radius)
	var fill_radius = radius - outline
	$Fill.scale = Vector2.ONE * (fill_radius / radius)
	$Outline/Outline2.scale = Vector2.ONE * (radius - outline*2/3) / radius
	$Outline/Outline3.scale = Vector2.ONE * (radius - outline/3) / radius
	if not radius:
		game_over.emit()


func start(start_position, starting_radius = 50.0):
	position = start_position
	velocity = Vector2.ZERO
	set_radius(starting_radius)
	visible = true
	absorbable = true
	fade_in(2.0)
