extends Node2D

@export var mob_scene: PackedScene
var screen_size

@export var starting_size = 20
@export var min_mob_radius = 5
@export var max_mob_radius = 540 # placeholder value assuming 1080p, updated in _ready()

# Called when the node enters the scene tree for the first time.
func _ready():
	screen_size = get_viewport_rect().size
	max_mob_radius = min(screen_size.x, screen_size.y) / 8
	$StartButton.position = screen_size/2


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not $Player.radius:
		game_over()


func game_over():
	$UI.visible = false
	$StartButton.visible = true

func new_game():
	$Player.start(screen_size/2, starting_size)
	$MobTimer.start()
	$UI.visible = true
	

func _on_start_button_pressed():
	$StartButton.visible = false
	new_game()


func _on_mob_timer_timeout():
	# create a new mob instance
	var mob = mob_scene.instantiate()
	add_child(mob)
	
	# spawn mob with a randomized size
	mob.spawn(randf_new_mob_radius())
	
	
func randf_weighted(bias_value, weight=2):
	# generates a random number from 0-1 with a weighted probability distribution
	# weight should be >= 0
	# weight > 1 tends to return values close to bias_value, increasing weight skews distribution closer to bias_value
	# weight < 1 tends to return values farther from bias_value, decreasing weight skews distribution further from bias_value
	# weight = 0 returns 0 or 1, with probability inverse to distance from bias_value, e.g. bias_value=0.5 is a coin flip, bias_value=0.3 returns 30% 0's, 70% 1's
	# weight = 1 has the same distribution as randf()
	# bias_value outside 0-1 is valid, yielding less skewed distributions the further bias_value is outside 0-1, roughly equivalent to using weight closer to 1
	var rand_val = randf()
	var distance_from_bias = abs(bias_value - rand_val)
	var norm_scalar = bias_value
	if rand_val > bias_value:
		norm_scalar = 1-bias_value
	var scaled = 1
	if norm_scalar:
		scaled = distance_from_bias / norm_scalar
	var weighted = pow(scaled,weight)
	var unscaled = weighted * norm_scalar
	if rand_val < bias_value:
		return bias_value - unscaled
	else:
		return bias_value + unscaled
	
func randf_range_weighted(from, to, bias_value, weight=2):
	# generates a random number from 0-1 with a probability distribution more likely to return a number close to bias_value
	# coefficients determined experimentally using Excel, there is definitely a better mthod out there
	var value_range = to - from
	var bias_ratio = (bias_value - from) / value_range
	return randf_weighted(bias_ratio, weight) * value_range + from

func randf_new_mob_radius():
	return randf_range_weighted(min_mob_radius, max_mob_radius, $Player.radius/2, 2)
