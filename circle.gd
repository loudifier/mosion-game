extends Area2D

var velocity = Vector2.ZERO
@export var radius = 50.0
var base_radius = 378/2 # size of the sprite


var absorbable = false
@export var growth_factor = 1.0

# Called when the node enters the scene tree for the first time.
func _ready():
	set_radius(radius)
	$CollisionShape2D.shape.set_radius(base_radius)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	position += velocity * delta
	
	for area in get_overlapping_areas():
		if 'absorbable' in area and absorbable and area.absorbable:
			# collision detection seems to be off by 1 frame. Probably a better way to handle it, but performing a collision sanity check works
			if position.distance_to(area.position) < (radius + area.radius):
				absorb(area)

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
	
func get_area():
	return PI * pow(radius,2)
	
func set_area(_area):
	set_radius(sqrt(_area/PI))
