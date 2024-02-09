extends Area2D

var velocity = Vector2.ZERO
@export var radius = 50.0
var base_radius = 378/2 # size of the sprite


# if fade_status is set to a falsy value no fade will be applied in _process()
# if fade_status=='in' the circle will fade in
# if set to a truthy value other than 'in' the circle will fade out
var fade_status = null
var fade_time = 0

var absorbable = false
@export var growth_factor = 1.0

# Called when the node enters the scene tree for the first time.
func _ready():
	set_radius(radius)
	$CollisionShape2D.shape.set_radius(base_radius)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if get_node("/root/Main").play_state != get_node("/root/Main").states.PAUSE:
		position += velocity * delta
	
	for area in get_overlapping_areas():
		if 'absorbable' in area and absorbable and area.absorbable:
			# collision detection seems to be off by 1 frame. Probably a better way to handle it, but performing a collision sanity check works
			if position.distance_to(area.position) < (radius + area.radius):
				absorb(area)
				
	if fade_status:
		var color = get_modulate()
		if fade_status=='in':
			color.a = min(color.a + delta/fade_time, 1)
		else:
			color.a = max(color.a - delta/fade_time, 0)
		set_modulate(color)
		if color.a==0 or color.a==1:
			fade_status=null
	

func absorb(enemy):
	# when another circle (enemy) collides with this node either absorb or get absorbed by the enemy
		# the larger circle adjusts the size of both circles, the other circle does nothing
		if radius > enemy.radius:
			# first adjust the smaller circle and get the area delta in the process
			var small_starting_area = enemy.get_area()
			var distance = position.distance_to(enemy.position)
			enemy.set_radius(distance-radius)
			var small_ending_area = enemy.get_area()
			var area_delta = small_starting_area - small_ending_area
			
			# add absorbed area to larger circle, adusted by growth factor
			set_area(get_area() + area_delta * growth_factor)
			

func set_radius(new_radius):
	if new_radius < 0:
		absorbable = false
	radius = max(new_radius, 0)
	scale = Vector2.ONE * radius/base_radius
	update_color()
	
func update_color():
	var alpha = get_modulate().a
	var color = get_node("/root/Main").color_scale.get_color(radius)
	color.a = alpha
	set_modulate(color)
	
func get_area():
	return PI * pow(radius,2)
	
func set_area(_area):
	set_radius(sqrt(_area/PI))
	
func fade_in(fade_length):
	var color = get_modulate()
	color.a = 0
	set_modulate(color)
	fade_status = 'in'
	fade_time = fade_length
	
func fade_out(fade_length):
	var color = get_modulate()
	color.a = 1
	set_modulate(color)
	fade_status = 'out'
	fade_time = fade_length
