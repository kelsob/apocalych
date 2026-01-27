extends RefCounted
class_name WorldNameGenerator

## World Name Generator - procedurally generates elvish/Tolkien-style fantasy world names
## Pure syllabic generation for flowing, melodic names

# Elvish-inspired syllable components for building names
var prefixes: Array[String] = [
	"Ael", "Aer", "Ald", "Ama", "Ara", "Cal", "Cel", "El", "Elen", "Ereb",
	"Fin", "Gal", "Gon", "Him", "Ild", "Imla", "Lin", "Lor", "Mith", "Nal",
	"Nim", "Ol", "Pel", "Riv", "Sil", "Tel", "Than", "Thran", "Tir", "Val"
]

var middles: Array[String] = [
	"ad", "ar", "en", "dor", "ath", "and", "el", "eth", "ien", "in",
	"or", "rond", "ond", "in", "rim", "las", "dil", "win", "mar", "dar",
	"nor", "lor", "thir", "ril", "mor", "tar", "ven", "duin", "lon", "bar"
]

var suffixes: Array[String] = [
	"ion", "ien", "iel", "dor", "mir", "ath", "oth", "or", "il", "rin",
	"wen", "eth", "indor", "inor", "ador", "ond", "dir", "las", "th", "ril",
	"mar", "dil", "ien", "ien", "dor", "dor", "ion", "ion", "ath", "or"
]

## Generate a random world name (pure syllabic, elvish-style)
func generate_name() -> String:
	var name_type = randi() % 3
	
	match name_type:
		0:  # Short: Prefix + Suffix (2 syllables)
			return _generate_short_name()
		1:  # Medium: Prefix + Middle + Suffix (3 syllables)
			return _generate_medium_name()
		2:  # Long: Prefix + Middle + Middle + Suffix (4 syllables)
			return _generate_long_name()
	
	return "Eriador"

## Generate short name (2 syllables)
func _generate_short_name() -> String:
	var prefix = prefixes[randi() % prefixes.size()]
	var suffix = suffixes[randi() % suffixes.size()]
	
	return prefix + suffix

## Generate medium name (3 syllables)
func _generate_medium_name() -> String:
	var prefix = prefixes[randi() % prefixes.size()]
	var middle = middles[randi() % middles.size()]
	var suffix = suffixes[randi() % suffixes.size()]
	
	return prefix + middle + suffix

## Generate long name (4 syllables)
func _generate_long_name() -> String:
	var prefix = prefixes[randi() % prefixes.size()]
	var middle1 = middles[randi() % middles.size()]
	var middle2 = middles[randi() % middles.size()]
	var suffix = suffixes[randi() % suffixes.size()]
	
	return prefix + middle1 + middle2 + suffix
