class_name VirtualJoystick

extends Control

## A simple virtual joystick for touchscreens, with useful options.
## Github: https://github.com/MarcoFazioRandom/Virtual-Joystick-Godot

# modified from source repo, a bit mangled now.
# added PLAYER mode to have player follow touch point
# added WHEN_TOUCHED visibility mode
# incorporated modifications from issue 65 to get analog output, instead of 8 positions like a dpad
# added stuff to cache shader on launch

# EXPORTED VARIABLE

## The color of the button when the joystick is pressed.
@export var pressed_color := Color.GRAY

## If the input is inside this range, the output is zero.
@export_range(0, 200, 1) var deadzone_size : float = 10

## The max distance the tip can reach.
@export_range(0, 500, 1) var clampzone_size : float = 75

enum Joystick_mode {
	FIXED, ## The joystick doesn't move.
	DYNAMIC, ## Every time the joystick area is pressed, the joystick position is set on the touched position.
	FOLLOWING, ## When the finger moves outside the joystick area, the joystick will follow it.
	PLAYER ## Every time the joystick area is pressed, the joystick centers on the player
}

## If the joystick stays in the same position or appears on the touched position when touch is started
@export var joystick_mode := Joystick_mode.FIXED

enum Visibility_mode {
	ALWAYS, ## Always visible
	TOUCHSCREEN_ONLY, ## Visible on touch screens only
	WHEN_TOUCHED ## Visible only when touched
}

## If the joystick is always visible, or is shown only if there is a touchscreen
@export var visibility_mode := Visibility_mode.WHEN_TOUCHED

## If true, the joystick uses Input Actions (Project -> Project Settings -> Input Map)
@export var use_input_actions := true

@export var action_left := "ui_left"
@export var action_right := "ui_right"
@export var action_up := "ui_up"
@export var action_down := "ui_down"

# PUBLIC VARIABLES

## If the joystick is receiving inputs.
var is_pressed := false
var last_touch = Vector2.ZERO

# The joystick output.
var output := Vector2.ZERO

# PRIVATE VARIABLES

var _touch_index : int = -1

@onready var _base := $Base
@onready var _tip := $Base/Tip

@onready var _base_default_position : Vector2 = _base.position
@onready var _tip_default_position : Vector2 = _tip.position

@onready var _default_color : Color = _tip.modulate

# FUNCTIONS

func _ready() -> void:
	# draw off screen to avoid lag spike on first touch on android
	_update_joystick(Vector2(-500,-500))
	
	if not DisplayServer.is_touchscreen_available() and (visibility_mode == Visibility_mode.TOUCHSCREEN_ONLY or visibility_mode == Visibility_mode.WHEN_TOUCHED):
		hide()
		

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		last_touch = event.position
		if event.pressed:
			if _is_point_inside_joystick_area(event.position) and _touch_index == -1:
				if joystick_mode == Joystick_mode.DYNAMIC or joystick_mode == Joystick_mode.FOLLOWING or joystick_mode == Joystick_mode.PLAYER or (joystick_mode == Joystick_mode.FIXED and _is_point_inside_base(event.position)):
					if joystick_mode == Joystick_mode.DYNAMIC or joystick_mode == Joystick_mode.FOLLOWING:
						_move_base(event.position)
					_touch_index = event.index
					_tip.modulate = pressed_color
					_update_joystick(event.position)
					get_viewport().set_input_as_handled()
		elif event.index == _touch_index:
			_reset()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		last_touch = event.position
		if event.index == _touch_index:
			_update_joystick(event.position)
			get_viewport().set_input_as_handled()

func _process(delta):
	# _process called after _input
	# touch and hold is true when is_anything_pressed() is true, but no touch events are fired
	# touch pressed/unpressed events set/reset is_pressed
	if is_pressed:
		# catches touch and hold, but calls _update_joystick twice on touch pressed or dragged
		_update_joystick(last_touch)
	
	# show joystick at launch, then hide it
	# fixes lag spike at first touch on android. I think Tip/Base texture clipping mask implements a shader under the hood, something something OpenGL compiles shaders when first called... https://travismaynard.com/writing/caching-particle-materials-in-godot
	if $LoadTimer.is_stopped() and ($"../..".play_state == $"../..".states.STOP):
		_reset()
	

func _move_base(new_position: Vector2) -> void:
	_base.global_position = new_position - _base.pivot_offset * get_global_transform_with_canvas().get_scale()
	show()

func _move_tip(new_position: Vector2) -> void:
	_tip.global_position = new_position - _tip.pivot_offset * _base.get_global_transform_with_canvas().get_scale()

func _is_point_inside_joystick_area(point: Vector2) -> bool:
	var x: bool = point.x >= global_position.x and point.x <= global_position.x + (size.x * get_global_transform_with_canvas().get_scale().x)
	var y: bool = point.y >= global_position.y and point.y <= global_position.y + (size.y * get_global_transform_with_canvas().get_scale().y)
	return x and y

func _get_base_radius() -> Vector2:
	return _base.size * _base.get_global_transform_with_canvas().get_scale() / 2

func _is_point_inside_base(point: Vector2) -> bool:
	var _base_radius = _get_base_radius()
	var center : Vector2 = _base.global_position + _base_radius
	var vector : Vector2 = point - center
	if vector.length_squared() <= _base_radius.x * _base_radius.x:
		return true
	else:
		return false

func _update_joystick(touch_position: Vector2) -> void:
	var _base_radius = _get_base_radius()
	if joystick_mode == Joystick_mode.PLAYER:
		_move_base($"../../Player".position)
	var center : Vector2 = _base.global_position + _base_radius
	var vector : Vector2 = touch_position - center
	vector = vector.limit_length(clampzone_size)
	
	if joystick_mode == Joystick_mode.FOLLOWING and touch_position.distance_to(center) > clampzone_size:
		_move_base(touch_position - vector)
	
	_move_tip(center + vector)
	
	if vector.length_squared() > deadzone_size * deadzone_size:
		is_pressed = true
		output = (vector - (vector.normalized() * deadzone_size)) / (clampzone_size - deadzone_size)
	
		if use_input_actions:
			if output.x > 0:
				Input.action_press(action_right, output.x)
				Input.action_release(action_left)
			else:
				Input.action_press(action_left, -output.x)
				Input.action_release(action_right)
				
			if output.y > 0:
				Input.action_press(action_down, output.y)
				Input.action_release(action_up)
			else:
				Input.action_press(action_up, -output.y)
				Input.action_release(action_down)
				
	else:
		is_pressed = false
		output = Vector2.ZERO
		if use_input_actions:
			_reset_input()
	
	
func _update_input_action(action:String, value:float):
	print(action)
	if value > InputMap.action_get_deadzone(action):
		Input.action_press(action, value)
	elif Input.is_action_pressed(action):
		Input.action_release(action)

func _reset():
	is_pressed = false
	output = Vector2.ZERO
	_touch_index = -1
	_tip.modulate = _default_color
	_base.position = _base_default_position
	_tip.position = _tip_default_position
	if use_input_actions:
		_reset_input()
	if visibility_mode == Visibility_mode.WHEN_TOUCHED:
		hide()

func _reset_input():
	for action in [action_left, action_right, action_down, action_up]:
		Input.action_release(action)
