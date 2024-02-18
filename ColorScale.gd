extends Node

var colors = [Color.WHITE,Color.WHITE,Color.WHITE]
var background_color = Color.WHITE
var theme_name = ''
var scale_range = [0,1]
var current_theme

enum themes {
	EMOSIONAL,
	BRUTALIST,
	FESTIVUS,
	PRIDE,
	MILLENNIAL,
	MONAURAL,
	SAILGATING
}

func set_theme(theme):
	current_theme = theme
	if theme == themes.EMOSIONAL:
		# defult pastel blue-yellow-red colors
		theme_name = 'emosional'
		# yellow-red scale. Extra points along red end of spectrum for better balance
		colors = [Color('#FFF785'),
				  Color('#FFC767'),
				  Color('#F87A61'),
				  Color('#F06565')]
		background_color = Color('#78A1B0')
		
	if theme == themes.BRUTALIST:
		# grayscale
		theme_name = 'brutalist'
		colors = [Color('#555555'), Color('#888888'), Color('#AAAAAA'), Color('#BBBBBB')]
		background_color = Color('#333333')
		
	if theme == themes.FESTIVUS:
		# dark green-dark red color scale with gold background
		theme_name = 'festivus'
		colors = [Color('#165B33'), Color('#BB2528')]
		background_color = Color('#BA9E56')
		
	if theme == themes.PRIDE:
		# colors from HRC website
		theme_name = 'pride'
		# double each color to minimize transitions between main colors
		colors = [Color('#E40203'),Color('#E40203'),
				  Color('#FF8B00'),Color('#FF8B00'),
				  Color('#FEED00'),Color('#FEED00'),
				  Color('#008024'),Color('#008024'),
				  Color('#004DFF'),Color('#004DFF'),
				  Color('#750686'),Color('#750686')]
		# no (non-white) background color seems to be most common. Using a dark desaturated purple because it looks decent
		background_color = Color('#5C5170')
		
	if theme == themes.MILLENNIAL:
		theme_name = 'millennial'
		colors = [Color('#D5F7C6'),
				  Color('#CBF7F8'),
				  Color('#926AFF'),
				  Color('#FF926B'),
				  Color('#926AFF')]
		background_color = Color('#E0B8B8')
		
	if theme == themes.MONAURAL:
		theme_name = 'monaural'
		colors = [Color('#9FBDDD'),
				  Color('white'),
				  Color('EFE27C'),
				  Color('#D3C45F')]
		background_color = Color('#21234D')
		
	if theme == themes.SAILGATING:
		theme_name = 'sailgating'
		colors = [Color('#4B2E83'),
				  Color('#8371BC'),
				  Color('#B7A57A'),
				  Color('#85754D'),
				  Color('#B7A57A'),
				  Color('#8371BC')]
		background_color = Color('#444444')
		
func get_color(color_scale_position):
	var num_colors = len(colors)
	# return white if get_color is called before theme is set
	if not num_colors:
		return Color.WHITE
		
	# normalize position to 0-1
	color_scale_position = fmod(color_scale_position + scale_range[1] - 2*scale_range[0],scale_range[1]-scale_range[0]) / (scale_range[1]-scale_range[0])
	
	# determine which colors are on either side of position along color scale
	var low_index = int(color_scale_position * num_colors)
	var high_index = 0
	if color_scale_position < (num_colors-1.0)/num_colors:
		high_index = low_index + 1
		
	# interpolate between colors
	return colors[low_index].lerp(colors[high_index], fmod(color_scale_position,1.0/num_colors)*num_colors)



# color conversion adapted from python colorsys module
# not actually used, but could come in handy
func rgb_to_hls(r, g, b):
	var maxc = max(r, g, b)
	var minc = min(r, g, b)
	var sumc = (maxc+minc)
	var rangec = (maxc-minc)
	var l = sumc/2.0
	if minc == maxc:
		return [0.0, l, 0.0]
	var s
	if l <= 0.5:
		s = rangec / sumc
	else:
		s = rangec / (2.0-maxc-minc)  # Not always 2.0-sumc: gh-106498.
	var rc = (maxc-r) / rangec
	var gc = (maxc-g) / rangec
	var bc = (maxc-b) / rangec
	var h
	if r == maxc:
		h = bc-gc
	elif g == maxc:
		h = 2.0+rc-bc
	else:
		h = 4.0+gc-rc
	h = fmod(h/6.0, 1.0)
	return [h, l, s]

func hls_to_rgb(h, l, s):
	if s == 0.0:
		return [l, l, l]
	var m2
	if l <= 0.5:
		m2 = l * (1.0+s)
	else:
		m2 = l+s-(l*s)
	var m1 = 2.0*l - m2
	return [_v(m1, m2, h+(1.0/3)), _v(m1, m2, h), _v(m1, m2, h-(1.0/3))]
	
func _v(m1, m2, hue):
	hue = fmod(hue, 1.0)
	if hue < (1.0/6):
		return m1 + (m2-m1)*hue*6.0
	if hue < 0.5:
		return m2
	if hue < (2.0/3):
		return m1 + (m2-m1)*((2.0/3)-hue)*6.0
	return m1
