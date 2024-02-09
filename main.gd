extends Node2D

@export var mob_scene: PackedScene
var screen_size

@export var starting_size = 20
@export var min_mob_radius = 5
@export var max_mob_radius = 540 # placeholder value assuming 1080p, updated in _ready()

var ColorScale = load("res://ColorScale.gd")
var color_scale = ColorScale.new()

enum states {
	STOP,
	PLAY,
	PAUSE
}
var play_state = states.STOP

# Called when the node enters the scene tree for the first time.
func _ready():
	$TitleScreen.visible = true
	$HUD.visible = false
	$Options.visible = false
	$Pause.visible = false
	
	screen_size = get_viewport_rect().size
	max_mob_radius = min(screen_size.x, screen_size.y) / 8
	
	color_scale.set_theme(color_scale.themes.EMOSIONAL)
	color_scale.scale_range = [min_mob_radius, 2*max_mob_radius]
	$Background.color = color_scale.background_color
	
	$MobTimer.start()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func game_over():
	play_state = states.STOP
	$HUD.visible = false
	#$GameOver.visible = true
	$TitleScreen.visible = true

func new_game():
	play_state = states.PLAY
	$Player.start(screen_size/2, starting_size)
	$HUD.visible = true
	$TitleScreen.visible = false
	get_tree().call_group('mobs', 'fade_delete')
	
	
	
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
	var value_range = to - from
	var bias_ratio = (bias_value - from) / value_range
	return randf_weighted(bias_ratio, weight) * value_range + from

func randf_new_mob_radius():
	return randf_range_weighted(min_mob_radius, max_mob_radius, $Player.radius/2, 2)


func _on_options_button_pressed():
	$TitleScreen.visible = false
	$Pause.visible = false
	$Options.visible = true
	

# change background color based on game values, with tweaks to HLS
# using fixed background color, but may come in handy later
func update_background(color_value):
	var background_color = color_scale.get_color(color_value)
	var background_hls = color_scale.rgb_to_hls(background_color[0],background_color[1],background_color[2])
	#background_hls[0] += 0.5 # get complementary color
	background_hls[1] = 0.2
	background_hls[2] = 0.2
	var background_rgb = color_scale.hls_to_rgb(background_hls[0],background_hls[1],background_hls[2])
	$Background.color = Color(background_rgb[0],background_rgb[1],background_rgb[2])


func _on_mute_button_toggled(toggled_on):
	pass # Replace with function body.


func _on_theme_button_pressed():
	var num_themes = len(color_scale.themes)
	for theme in color_scale.themes:
		if color_scale.current_theme == color_scale.themes[theme]:
			color_scale.set_theme((color_scale.themes[theme]+1)%num_themes)
			break
			
	$Options/ThemeButton.text = color_scale.theme_name
	$Background.color = color_scale.background_color
	$Player.update_color()
	get_tree().call_group('mobs', 'update_color')


func _on_back_button_pressed():
	$Options.visible = false
	if play_state == states.STOP:
		$TitleScreen.visible = true
	else: # game is paused
		$Pause.visible = true


func resume():
	play_state = states.PLAY
	$Pause.visible = false
	$HUD/PauseButton.visible = true
	$MobTimer.paused = false


func pause():
	play_state = states.PAUSE
	$Pause.visible = true
	$HUD/PauseButton.visible = false
	$MobTimer.paused = true
