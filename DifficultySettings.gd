extends Node

var level = 1

func min_mob_radius(player_radius):
	# 0.5 * player size, up to 0.9, 0.05 per level. Absolute min of 3
	return max(min(0.5 + 0.05*(level-1), 0.9) * player_radius, 3)
	
func mob_max_radius(screen_size):
	# 10% of screen min up to 40% screen min in 1% steps
	if not screen_size: # handle getting called before main._ready()
		return 100
	return min(0.01*(level+9), 0.4) * min(screen_size.x, screen_size.y)
	
func mob_size_weight():
	# starting at 2.0 up to level 5, decrease by 0.1 per level. 0.5 min
	return max(2.0 - (min(level - 6, 0) * 0.1), 0.5)
	
func spawn_time():
	# 1/sec up to 4/sec at level 20
	return max(1.0 - (1.0/20)*(level-1), 0.25)
	
func mob_min_speed():
	return 20
	
func mob_max_speed():
	# 100, increasing by 10 every level
	return 100 + 10*(level-1)
