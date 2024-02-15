# MIT License

# Copyright (c) 2023-present Poing Studios

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# example code from https://github.com/poing-studios/godot-admob-plugin
# minor changes to work with mosion-game

extends Control

var interstitial_ad : InterstitialAd
var interstitial_ad_load_callback := InterstitialAdLoadCallback.new()
var full_screen_content_callback := FullScreenContentCallback.new()

var ad_loaded = false

# test unit ID: "ca-app-pub-3940256099942544/1033173712"
var unit_id = "ca-app-pub-3940256099942544/1033173712"

func _ready():
	interstitial_ad_load_callback.on_ad_failed_to_load = on_interstitial_ad_failed_to_load
	interstitial_ad_load_callback.on_ad_loaded = on_interstitial_ad_loaded

	full_screen_content_callback.on_ad_clicked = func() -> void:
		print("on_ad_clicked")
	full_screen_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
		$"../DebugText".text = ("ad dismissed")
		destroy()
		$Loading.visible = false
		$"..".new_game()
		
	full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(ad_error : AdError) -> void:
		print("on_ad_failed_to_show_full_screen_content")
	full_screen_content_callback.on_ad_impression = func() -> void:
		print("on_ad_impression")
	full_screen_content_callback.on_ad_showed_full_screen_content = func() -> void:
		print("on_ad_showed_full_screen_content")

func load_ad():
	$"../DebugText".text = 'load clicked'
	InterstitialAdLoader.new().load(unit_id, AdRequest.new(), interstitial_ad_load_callback)

func on_interstitial_ad_failed_to_load(adError : LoadAdError) -> void:
	$"../DebugText".text = (adError.message)
	destroy()
	
func on_interstitial_ad_loaded(interstitial_ad : InterstitialAd) -> void:
	print("interstitial ad loaded" + str(interstitial_ad._uid))
	interstitial_ad.full_screen_content_callback = full_screen_content_callback
	self.interstitial_ad = interstitial_ad
	
	$"../DebugText".text = 'ad loaded'
	ad_loaded = true
	if not $AdTimer.is_stopped():
		show_ad()
	

func show_ad():
	$"../DebugText".text = 'show clicked'
	if interstitial_ad:
		$"..".play_state = $"..".states.AD
		interstitial_ad.show()
	else:
		$Loading.visible = false
		$"..".new_game()

func _on_destroy_pressed():
	destroy()
	

func destroy():
	ad_loaded = false
	if interstitial_ad:
		interstitial_ad.destroy()
		interstitial_ad = null #need to load again
		#DestroyButton.disabled = true
		#ShowButton.disabled = true
		#LoadButton.disabled = false

func wait(timeout):
	$AdTimer.start(timeout)
	$"../HUD".visible = false
	$"../TitleScreen".visible = false
	$"../Pause".visible = false
	$"../GameOver".visible = false
	$"../Options".visible = false
	$Loading.visible = true
	

func _on_ad_timer_timeout():
	if not (($"..".play_state == $"..".states.AD) or ($"..".play_state == $"..".states.PLAY)):
		$Loading.visible = false
		$"..".new_game()
