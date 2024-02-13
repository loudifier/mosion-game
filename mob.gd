extends "res://circle.gd"

var blur_outline = 3.0

var delete_on_fade_out = false

# Called when the node enters the scene tree for the first time.
func _ready():
	$VisibleOnScreenNotifier2D.set_rect(Rect2(-base_radius,-base_radius,2*base_radius,2*base_radius))
	super._ready()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	super._process(delta)
	

func spawn(spawn_radius, min_speed, max_speed):
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
	
	# boost speed for smaller mobs
	var boost = pow(get_node("/root/Main/Player").radius / spawn_radius, 2)
	velocity *= (1 + randf_range(0, boost))
	
	# initialize radius
	set_radius(spawn_radius)
	
	# enable absorption
	absorbable = true
	

func _on_screen_exited():
	#despawn mob when it goes off screen
	queue_free()
	
func fade_delete():
	fade_out(2.0)
	delete_on_fade_out = true
	# don't actually do anything special to delete
	# just let mob continue off screen
	
func absorb(enemy):
	if delete_on_fade_out:
		if enemy.is_in_group('mobs') and enemy.delete_on_fade_out:
			# if being deleted, only absorb enemy if mob is also being deleted
			super.absorb(enemy)
	else:
		# if not being deleted, process regular absorb
		super.absorb(enemy)
		
		

func set_radius(new_radius):
	super.set_radius(new_radius)
	if radius:
		$Blur.scale = Vector2.ONE * ((radius+blur_outline) / radius)
		$Blur/Blur2.scale = Vector2.ONE * ((radius+blur_outline*2/3) / radius)
		$Blur/Blur3.scale = Vector2.ONE * ((radius+blur_outline/3) / radius)
	else:
		$Blur.visible = false
