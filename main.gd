extends Node2D

# game save data
var save_file = 'user://save.json'

# base scene for enemy circles
@export var mob_scene: PackedScene

# global for calculations based on screen size
var screen_size

# difficulty parameters
# needs to be refactored. Parameters affecting difficult spread around project
@export var starting_size = 20
@export var min_mob_radius = 5
@export var max_mob_radius = 135 # placeholder value assuming 1080p, updated based on screen size in _ready()
# mob speed in mob scene
# mob spawn frequency in MobTimer 
# mob spawn size in randf_new_mob_radius()
# player growth rate in player scene _ready
# player movement (speed, friction) in player scene


# class to manage themes
var ColorScale = load("res://ColorScale.gd")
var color_scale = ColorScale.new()

# play states
enum states {
	STOP,
	PLAY,
	PAUSE
}
var play_state = states.STOP

# variables related to scoring and level transitions
var score = 0
var level = 1
var level_threshold = 200.0 # level up when player radius passes threshold
var per_level_scaling = level_threshold/starting_size
var score_multiplier = 1.0  # current level scaling for scoring, accumulates and compounds as you level up
var level_transition_length = 5.0 # time in seconds
var level_time = 0 # time remaining in the current level transition

# data to keep track of for high score purposes
var high_score = 0
var high_score_circles = {} # data needed to recreate a screenshot of the moment the high score was achieved 
var largest_size = 0 # largest player radius in the current (or most recent) game
var last_game_circles = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	$TitleScreen.visible = true
	$HUD.visible = false
	$Options.visible = false
	$Pause.visible = false
	$GameOver.visible = false
	$Joystick.visible = false
	
	screen_size = get_viewport_rect().size
	get_tree().get_root().size_changed.connect(_screen_size_changed)
	
	max_mob_radius = min(screen_size.x, screen_size.y) / 8.0
	
	color_scale.set_theme(color_scale.themes.EMOSIONAL)
	color_scale.scale_range = [min_mob_radius, 2*max_mob_radius]
	$Background.color = color_scale.background_color
	
	$MobTimer.start()
	
	# read save file after everything has been initialized so default values can be overridden
	read_save()
	
	
	
func read_save():
	var f = FileAccess.open(save_file, FileAccess.READ)
	if FileAccess.file_exists(save_file):
		while f.get_position() < f.get_length():
			var json_str = f.get_line()
			var json = JSON.new()
			json.parse(json_str)
			var save_data = json.get_data()
			high_score_circles = save_data #includes other junk, but shouldn't hurt functionality
			high_score = save_data['high_score']
			set_theme(save_data['theme'])
			# volume/mute settings

func save_game():
	var f = FileAccess.open(save_file, FileAccess.WRITE)
	var save_data = high_score_circles
	save_data['theme'] = color_scale.current_theme
	save_data['high_score'] = high_score
	# volume/mute settings
	var json_str = JSON.stringify(save_data)
	f.store_line(json_str)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# most game logic is handled in (or called from) circle/player/mob _process functions
	# game state and UI primarily handled by signal handlers
	
	# level up and level up transition
	if $Player.radius > level_threshold and level_time==0:
		level_time = level_transition_length
	
	if level_time:
		# transition to next level, frame by frame
		level_time = max(level_time - delta, 0)
		
		# number of transition frames used to proportionally scale values
		var num_transition_frames = level_transition_length / delta
		
		# scale the value up
		score_multiplier *= pow(per_level_scaling, 1.0/num_transition_frames)
		
		# scale circle sizes and positions down
		var frame_scaling = pow(1.0/per_level_scaling, 1.0/num_transition_frames)
		var xmid = screen_size.x/2
		var ymid = screen_size.y/2
		
		$Player.set_radius($Player.radius * frame_scaling)
		$Player.velocity *= frame_scaling
		$Player.position.x = xmid + frame_scaling * ($Player.position.x - xmid)
		$Player.position.y = ymid + frame_scaling * ($Player.position.y - ymid)
		
		for mob in get_tree().get_nodes_in_group('mobs'):
			mob.set_radius(mob.radius * frame_scaling)
			mob.velocity *= frame_scaling
			mob.position.x = xmid + frame_scaling * (mob.position.x - xmid)
			mob.position.y = ymid + frame_scaling * (mob.position.y - ymid)
		
		# increment level if this is the last frame of the transition
		if level_time == 0:
			level += 1

func game_over():
	play_state = states.STOP
	if score > high_score:
		high_score = score
		high_score_circles = last_game_circles.duplicate()
		high_score_circles['screen'] = {'x'=screen_size.x, 'y'=screen_size.y}
		$GameOver/ScoreLabel.text = 'new high score!'
	else:
		$GameOver/ScoreLabel.text = 'your score: ' + score_string(score)
	$GameOver/HighScoreLabel.text = 'high score: ' + score_string(high_score)
	$HUD.visible = false
	$GameOver.visible = true
	$Joystick.visible = false
	
	save_game()

func new_game():
	$Player.start(screen_size/2, starting_size)
	$HUD.visible = true
	$Joystick.visible = true
	$TitleScreen.visible = false
	$GameOver.visible = false
	get_tree().call_group('mobs', 'fade_delete')
	score = 0
	$HUD/ScoreLabel.text = str(0)
	score_multiplier = 1.0
	level = 1
	largest_size = starting_size
	
	play_state = states.PLAY
	
	
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
	save_game()


func _on_theme_button_pressed():
	var num_themes = len(color_scale.themes)
	for theme in color_scale.themes:
		if color_scale.current_theme == color_scale.themes[theme]:
			set_theme((color_scale.themes[theme]+1)%num_themes)
			break
	save_game()

func set_theme(theme):
	color_scale.set_theme(theme)
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
	$Joystick.visible = true
	$MobTimer.paused = false


func pause():
	play_state = states.PAUSE
	$Pause.visible = true
	$HUD/PauseButton.visible = false
	$Joystick.visible = false
	$MobTimer.paused = true
	


func add_score(increase):
	score += increase * score_multiplier
	$HUD/ScoreLabel.text = score_string(score)
	
	last_game_circles['player'] = {
		'radius' = $Player.radius,
		'x' = $Player.position.x,
		'y' = $Player.position.y
	}
	last_game_circles['mobs'] = []
	for mob in get_tree().get_nodes_in_group('mobs'):
		last_game_circles['mobs'].append({
			'radius' = mob.radius,
			'x' = mob.position.x,
			'y' = mob.position.y
		})
		
	largest_size = max(largest_size, $Player.radius)

func score_string(score_num):
	var score_str = ''
	if score_num < 10:
		score_str = str(snapped(score_num,0.1))
	else:
		score_str = str(round(score_num))
	return score_str



func _screen_size_changed():
	screen_size = get_viewport_rect().size


func _on_main_menu_button_pressed():
	$HUD.visible = false
	$Pause.visible = false
	$GameOver.visible = false
	$TitleScreen.visible = true
