extends Node

# just handling the melody for now, planning to add other elements later

func _process(delta):
	if get_node("/root/Main").mute or not get_node("/root/Main").music_vol:
		$Melody.stop()
	else:
		if not $Melody.playing:
			$Melody.play()
		
		# if fading playback in/out or adjusting volume, apply a smooth ramp
		var target_vol_db = -40 * (1- get_node("/root/Main").music_vol)
		var db_per_frame = 0.5
		if $Melody.volume_db < target_vol_db:
			$Melody.volume_db = min($Melody.volume_db + db_per_frame, target_vol_db)
		if $Melody.volume_db > target_vol_db:
			$Melody.volume_db = max($Melody.volume_db - db_per_frame, target_vol_db)
