extends "res://circle.gd"

@export var outline = 3.0

@export var move_speed = 10
@export var friction = 0.01

signal game_over

signal add_score

var absorb_sound_length = 0.15
var absorb_up_position = 0
var absorb_down_position = 0

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
	
	# WASD and virtual joystick mapped to ui_left/right/down/up
	accel = Input.get_vector('ui_left','ui_right','ui_up','ui_down')
	
	velocity += accel * move_speed - velocity * friction
	

func set_radius(new_radius):
	if new_radius > radius and get_node("/root/Main").play_state == get_node("/root/Main").states.PLAY:
		add_score.emit(new_radius - radius)
	super.set_radius(new_radius)
	get_node("/root/Main").update_difficulty()
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

func absorb(enemy):
	super.absorb(enemy)
	
	if radius > enemy.radius:
		play_up()
	else:
		if $DownTimer.is_stopped():
			$AbsorbDown.play(absorb_down_position)
		$DownTimer.start(absorb_sound_length)

func _on_up_timer_timeout():
	absorb_up_position = $AbsorbUp.get_playback_position()
	$AbsorbUp.stop()
	
func _on_down_timer_timeout():
	absorb_down_position = $AbsorbDown.get_playback_position()
	$AbsorbDown.stop()

func play_up():
	if get_node("/root/Main").effects_vol and not get_node("/root/Main").mute:
		# convert effects volume to dB playback level
		$AbsorbUp.volume_db = get_volume_db()
		if $UpTimer.is_stopped():
			$AbsorbUp.play(absorb_up_position)
		$UpTimer.start(absorb_sound_length)
	
func play_down():
	if get_node("/root/Main").effects_vol and not get_node("/root/Main").mute:
		# convert effects volume to dB playback level
		$AbsorbDown.volume_db = get_volume_db()
		if $DownTimer.is_stopped():
			$AbsorbDown.play(absorb_up_position)
		$DownTimer.start(absorb_sound_length)

func get_volume_db():
	return -40 * (1- get_node("/root/Main").effects_vol) - 10
