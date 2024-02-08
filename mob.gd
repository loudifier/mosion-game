extends "res://circle.gd"

@export var min_speed = 20
@export var max_speed = 150

var spawn_area = 0 # value used to keep track of spawning progress

# Called when the node enters the scene tree for the first time.
func _ready():
	$VisibleOnScreenNotifier2D.set_rect(Rect2(-base_radius,-base_radius,2*base_radius,2*base_radius))
	super._ready()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if spawn_area:
		# expand mob to hit edge of screen, using available area from spawn_area
		# kind of buggy and opens exploit of sitting on the edges absorbing new mobs before they are full size
		# determine how far mob is from edge of screen
		var screen_size = get_viewport_rect().size
		var edge_distance = min(min(position.x, screen_size.x-position.x),min(position.y, screen_size.y-position.y))
		
		# calculate area to edge of screen, how much area to add to mob
		var edge_area = PI * pow(edge_distance,2)
		var add_area = edge_area - get_area()
		if add_area < spawn_area:
			set_area(get_area() + add_area)
		else:
			set_area(get_area() + spawn_area)
		spawn_area = max(spawn_area-add_area, 0)
	
	super._process(delta)
	
	# delete mob if it 
	#if not radius:
	#	queue_free()

func spawn(spawn_radius):
	# set the mob's spawn point
	#position = randf_spawn_point(spawn_radius)
	
	# randomize spawn point around edge of screen
	var screen_size = get_viewport_rect().size
	var spawn_position = randf_range(0, 2*screen_size.x + screen_size.y)
	#var spawn_point = Vector2.ZERO
	if spawn_position < screen_size.x:
		# spawn from top of screen
		position.x = spawn_position
		position.y = -(spawn_radius - 0.01)
		velocity = Vector2.DOWN
	elif spawn_position < (screen_size.x + screen_size.y):
		# spawn from right
		position.x = screen_size.x + (spawn_radius - 0.01)
		position.y = spawn_position - screen_size.x
		velocity = Vector2.LEFT
	elif spawn_position < (2*screen_size.x + screen_size.y):
		#spawn from bottom
		position.x = spawn_position - screen_size.x - screen_size.y
		position.y = screen_size.y + (spawn_radius - 0.01)
		velocity = Vector2.UP
	else:
		#spawn from left
		position.x = -(spawn_radius - 0.01)
		position.y = spawn_position - (2*screen_size.x - screen_size.y)
		velocity = Vector2.RIGHT
	
	# randomize speed and direction
	velocity = randf_range(min_speed, max_speed) * velocity.rotated(randf_range(-PI/4,PI/4))
		
	
	# set the mob's speed and direction
	#velocity = Vector2(randf_range(min_speed, max_speed), 0.0)
	#velocity = velocity.rotated($MobPath/MobSpawnLocation.rotation + randf_range(0,PI/2))
	
	# initialize the radius to a small non-zero value and set the initial area to grow to
	# fun idea, but doesn't work very well in practice
	#set_radius(0.01)
	#spawn_area = PI * pow(spawn_radius,2)
	set_radius(spawn_radius)
	
	# enable absorption
	absorbable = true
	

func randf_spawn_point(spawn_radius):
	# define a path around the perimeter to determine where the mob can spawn
	var screen_size = get_viewport_rect().size
	$MobPath.curve.add_point(Vector2(0,0))
	$MobPath.curve.add_point(Vector2(screen_size.x,0))
	$MobPath.curve.add_point(Vector2(screen_size.x, screen_size.y))
	$MobPath.curve.add_point(Vector2(0,screen_size.y))
	$MobPath.curve.add_point(Vector2(0,0))
	
	# randomize spawn point
	$MobPath/MobSpawnLocation.set_progress_ratio(randf())
	var spawn_point = $MobPath/MobSpawnLocation.position
	
	# start mob just barely on screen
	return spawn_point + (spawn_radius - 0.01) * Vector2(1,0).rotated($MobPath/MobSpawnLocation.rotation - PI/2)
	

func _on_screen_exited():
	#despawn mob when it goes off screen
	queue_free()
