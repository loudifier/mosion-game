extends Node2D

# game save data
var save_file = 'user://save.json'

# base scene for enemy circles
@export var mob_scene: PackedScene

# global for calculations based on screen size
var screen_size

# difficulty parameters
var starting_size = 20
var mob_min_radius
var mob_max_radius
var mob_size_weight
var mob_min_speed
var mob_max_speed
# other parameters affecting difficult spread around project
# bias value for mob size weighted RNG (mob radius/2) in randf_new_mob_radius() below
# MobTimer time, inverse of spawn rate
# small mobs bonus speed in mob scene
# player growth rate in player scene _ready
# player movement (speed, friction) in player scene

# class to set difficulty
var DifficultySettings = load("res://DifficultySettings.gd")
var difficulty = DifficultySettings.new()

# class to manage themes
var ColorScale = load("res://ColorScale.gd")
var color_scale = ColorScale.new()

# play states
enum states {
	STOP,
	PLAY,
	PAUSE,
	AD
}
var play_state = states.STOP

# control schemes for touch/click input
enum control_styles {
	FOLLOW, # player circle will move towards where user clicks
	JOYSTICK # joystick is placed wherever user clicks, drag in the direction you want the player circle to go
}
var control_style = control_styles.FOLLOW

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

# audio settings
var effects_vol = 0.8 # scale from 0-1. Children responsible for converting to useful dB scale
var music_vol = 0.8
var mute = false

# ads
var ad_free = false # either purchased or manual override
var ad_load_timeout = 5.0
var first_game = true

# Called when the node enters the scene tree for the first time.
func _ready():
	get_tree().set_quit_on_go_back(false) # keep android back button from quitting game
	
	$TitleScreen.visible = true
	$HUD.visible = false
	$Options.visible = false
	$Pause.visible = false
	$GameOver.visible = false
	$Joystick.visible = true
	
	screen_size = get_viewport_rect().size
	get_tree().get_root().size_changed.connect(_screen_size_changed)
	
	level_threshold = (5.0/16) * min(screen_size.x, screen_size.y)
	difficulty.level = 1
	update_difficulty()
	
	color_scale.set_theme(color_scale.themes.EMOSIONAL)
	color_scale.scale_range = [mob_min_radius, 2*mob_max_radius]
	$Background.color = color_scale.background_color
	
	$MobTimer.start()
	
	# read save file after everything has been initialized so default values can be overridden
	read_save()
	
	# OS-specific settings and ads
	if OS.get_name() != 'Android':
		ad_free = true
		$Options/ControlLabel.text = 'click controls'
		$Options/WASDLabel.visible = true
	MobileAds.initialize()
	
	# uncomment when creating a new icon
	#draw_icon()
	
	
func read_save():
	var f = FileAccess.open(save_file, FileAccess.READ)
	if FileAccess.file_exists(save_file):
		while f.get_position() < f.get_length():
			var json_str = f.get_line()
			var json = JSON.new()
			json.parse(json_str)
			var save_data = json.get_data()
			
			high_score_circles = save_data #includes other junk, but shouldn't hurt functionality
			if save_data.has('high_score'):
				high_score = save_data['high_score']
			if save_data.has('theme'):
				set_theme(save_data['theme'])
			if save_data.has('control_style'):
				set_control_style(save_data['control_style'])
			if save_data.has('mute'):
				mute = save_data['mute']
				_on_mute_button_toggled(mute, false)
			if save_data.has('music_vol'):
				music_vol = save_data['music_vol']
				$Options/MusicSlider.set_value_no_signal(100*music_vol)
			if save_data.has('effects_vol'):
				effects_vol = save_data['effects_vol']
				$Options/EffectsSlider.set_value_no_signal(100*effects_vol)

func save_game():
	var f = FileAccess.open(save_file, FileAccess.WRITE)
	
	var save_data = high_score_circles
	save_data['theme'] = color_scale.current_theme
	save_data['control_style'] = control_style
	save_data['high_score'] = high_score
	save_data['mute'] = mute
	save_data['music_vol'] = music_vol
	save_data['effects_vol'] = effects_vol
	
	var json_str = JSON.stringify(save_data)
	f.store_line(json_str)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# most game logic is handled in (or called from) circle/player/mob _process functions
	# game state and UI primarily handled by signal handlers
	
	# level up and level up transition
	if $Player.radius > level_threshold and level_time==0:
		level_time = level_transition_length
		difficulty.level += 1
		update_difficulty()
	
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


func update_difficulty():
	mob_min_radius = difficulty.min_mob_radius($Player.radius)
	mob_max_radius = difficulty.mob_max_radius(screen_size)
	mob_size_weight = difficulty.mob_size_weight()
	mob_min_speed = difficulty.mob_min_speed()
	mob_max_speed = difficulty.mob_max_speed()
	$MobTimer.wait_time = difficulty.spawn_time()

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
	
	if not ad_free:
		$InterstitialAd.load_ad()
	
	save_game()

func _on_new_game_clicked():
	if first_game or ad_free:
		first_game = false
		new_game()
		return
		
	if $InterstitialAd.ad_loaded:
		$InterstitialAd.show_ad()
	else:
		$InterstitialAd.wait(ad_load_timeout)

func new_game():
	$Joystick/VirtualJoystick._reset()
	$Player.start(screen_size/2, starting_size)
	difficulty.level = 1
	update_difficulty()
	$HUD.visible = true
	$Joystick.visible = true
	$TitleScreen.visible = false
	$GameOver.visible = false
	$Pause.visible = false
	get_tree().call_group('mobs', 'fade_delete')
	$MobTimer.start()
	score = 0
	$HUD/ScoreLabel.text = str(0)
	score_multiplier = 1.0
	largest_size = starting_size
	
	play_state = states.PLAY
	
	
func _on_mob_timer_timeout():
	# create a new mob instance
	var mob = mob_scene.instantiate()
	add_child(mob)
	
	# spawn mob with a randomized size
	mob.spawn(randf_new_mob_radius(), mob_min_speed, mob_max_speed)
	
	
func draw_icon():
	# position static player and enemy circles to get a screenshot for creating an updated icon
	$TitleScreen.visible = false
	$MobTimer.paused = true
	$Player.start(screen_size/2, 180)
	level_threshold = $Player.radius *2
	var mob = mob_scene.instantiate()
	add_child(mob)
	mob.spawn(75, 0, 0)
	var offset = 160
	mob.position = Vector2($Player.position.x + offset, $Player.position.y + offset)
	
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
	return randf_range_weighted(mob_min_radius, mob_max_radius, $Player.radius/2, mob_size_weight)


func _on_options_button_pressed():
	$TitleScreen.visible = false
	$Pause.visible = false
	show_confirm(false)
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


func _on_mute_button_toggled(toggled_on, save=true):
	mute = toggled_on
	$Options/MuteButton.set_pressed_no_signal(toggled_on)
	$Pause/MuteButton.set_pressed_no_signal(toggled_on)
	$TitleScreen/MuteButton.set_pressed_no_signal(toggled_on)
	if save:
		save_game()
	
func _on_music_slider_drag_ended(value_changed):
	music_vol = $Options/MusicSlider.value / 100.0
	save_game()

func _on_effects_slider_drag_ended(value_changed):
	effects_vol = $Options/EffectsSlider.value / 100.0
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

func _on_control_button_pressed():
	var num_styles = len(control_styles)
	for style in control_styles:
		if control_style == control_styles[style]:
			set_control_style((control_styles[style]+1)%num_styles)
			break
	save_game()
	
func set_control_style(style):
	control_style = style
	if style == control_styles.FOLLOW:
		$Options/ControlButton.text = 'follow'
		$Joystick/VirtualJoystick.joystick_mode = $Joystick/VirtualJoystick.Joystick_mode.PLAYER
	elif style == control_styles.JOYSTICK:
		$Options/ControlButton.text = 'joystick'
		$Joystick/VirtualJoystick.joystick_mode = $Joystick/VirtualJoystick.Joystick_mode.DYNAMIC

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
	show_confirm(false)


func pause():
	play_state = states.PAUSE
	$Pause.visible = true
	$HUD/PauseButton.visible = false
	$Joystick.visible = false
	$MobTimer.paused = true
	
func _on_new_button_pressed():
	show_confirm(true)
	
func show_confirm(show_confirm):
	$Pause/NewButton.visible = !show_confirm
	$Pause/ConfirmLabel.visible = show_confirm
	$Pause/YesButton.visible = show_confirm
	$Pause/NoButton.visible = show_confirm
	
func _on_yes_button_pressed():
	show_confirm(false)
	$HUD/PauseButton.visible = true
	$MobTimer.paused = false
	_on_new_game_clicked()
	
func _on_no_button_pressed():
	show_confirm(false)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_esc_pressed()

func _on_esc_pressed():
	if $Options.visible:
		_on_back_button_pressed()
	elif play_state == states.PLAY:
		pause()
	elif play_state == states.PAUSE:
		if $Pause/ConfirmLabel.visible:
			show_confirm(false)
		else:
			resume()

func _notification(what):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# handle android back button
		_on_esc_pressed()
	
	if (what == NOTIFICATION_APPLICATION_FOCUS_OUT) or (what == NOTIFICATION_APPLICATION_PAUSED):
		# focus lost (or paused on android)
		if play_state == states.PLAY:
			pause()

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
		for i in range(score_str.length()-3, 0, -3):
			score_str = score_str.insert(i, ",")
	return score_str



func _screen_size_changed():
	screen_size = get_viewport_rect().size


func _on_main_menu_button_pressed():
	$HUD.visible = false
	$Pause.visible = false
	$GameOver.visible = false
	$TitleScreen.visible = true

