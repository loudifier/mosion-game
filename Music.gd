extends Node

# messy cascade of if statements. Probably a more elegant way of managing music, but this works
# probably also missing some corner cases around mute, volume changes

var last_playback_position = 0

func _process(delta):
	if get_node("/root/Main").mute or not get_node("/root/Main").music_vol:
		if $Melody.playing:
			last_playback_position = $Melody.get_playback_position()
			$Melody.stop()
			$DrumBass.stop()
			$Ambient.stop()
	else:
		if not $Melody.playing:
			$Melody.play(last_playback_position)
		
		# if fading playback in/out or adjusting volume, apply a smooth ramp
		var target_vol_db = -40 * (1- get_node("/root/Main").music_vol)
		var db_per_frame = 0.25
		if $Melody.volume_db < target_vol_db:
			$Melody.volume_db = min($Melody.volume_db + db_per_frame, target_vol_db)
		if $Melody.volume_db > target_vol_db:
			$Melody.volume_db = max($Melody.volume_db - db_per_frame, target_vol_db)
			
		# handle additional tracks depending on current level
		var level = $"..".difficulty.level
		
		if level < 2:
			if $DrumBass.playing:
				$DrumBass.volume_db = max($DrumBass.volume_db - db_per_frame, -40)
				if $DrumBass.volume_db == -40:
					$DrumBass.stop()
		else:
			if not $DrumBass.playing:
				$DrumBass.play($Melody.get_playback_position())
			if $DrumBass.volume_db < target_vol_db:
				$DrumBass.volume_db = min($DrumBass.volume_db + db_per_frame, target_vol_db)
			if $DrumBass.volume_db > target_vol_db:
				$DrumBass.volume_db = max($DrumBass.volume_db - db_per_frame, target_vol_db)
				
		if level < 3:
			if $Ambient.playing:
				$Ambient.volume_db = max($Ambient.volume_db - db_per_frame, -40)
				if $Ambient.volume_db == -40:
					$Ambient.stop()
		else:
			if not $Ambient.playing:
				$Ambient.play($Melody.get_playback_position())
			if $Ambient.volume_db < target_vol_db:
				$Ambient.volume_db = min($Ambient.volume_db + db_per_frame, target_vol_db)
			if $Ambient.volume_db > target_vol_db:
				$Ambient.volume_db = max($Ambient.volume_db - db_per_frame, target_vol_db)
