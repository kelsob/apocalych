extends RefCounted
class_name WorldNameGenerator

## World Name Generator - procedurally generates fantasy world names

# Syllable components for building names
var prefixes: Array[String] = [
	"Eld", "Aer", "Mor", "Val", "Thal", "Kor", "Zeph", "Nyr", "Drak", "Syl",
	"Quen", "Vyr", "Lyr", "Myth", "Arc", "Cel", "Ether", "Nex", "Prim", "Vex",
	"Zar", "Xyl", "Kyr", "Nyx", "Vex", "Zeph", "Quor", "Myl", "Pyr", "Vyl"
]

var middles: Array[String] = [
	"en", "ar", "or", "ir", "ur", "al", "el", "il", "ul", "an",
	"in", "on", "un", "ath", "eth", "ith", "oth", "uth", "and", "end",
	"ind", "ond", "und", "ara", "era", "ira", "ora", "ura", "ala", "ela"
]

var suffixes: Array[String] = [
	"ia", "ia", "ion", "ion", "ia", "ia", "ium", "ium", "ia", "ia",
	"eth", "ath", "ith", "oth", "uth", "en", "an", "in", "on", "un",
	"ara", "era", "ira", "ora", "ura", "ala", "ela", "ila", "ola", "ula"
]

var standalone_words: Array[String] = [
	"Shadow", "Storm", "Crystal", "Ancient", "Eternal", "Mystic", "Sacred",
	"Frozen", "Burning", "Golden", "Silver", "Iron", "Steel", "Diamond",
	"Emerald", "Sapphire", "Ruby", "Amber", "Jade", "Pearl", "Obsidian",
	"Void", "Star", "Moon", "Sun", "Dawn", "Dusk", "Twilight", "Night",
	"Day", "Light", "Dark", "Fire", "Ice", "Wind", "Earth", "Water"
]

var standalone_suffixes: Array[String] = [
	"realm", "land", "world", "kingdom", "empire", "domain", "realm",
	"lands", "worlds", "kingdoms", "empires", "domains", "realm",
	"realm", "land", "world", "kingdom", "empire", "domain"
]

## Generate a random world name
func generate_name() -> String:
	var name_type = randi() % 3
	
	match name_type:
		0:  # Syllable-based: Prefix + Middle + Suffix
			return _generate_syllable_name()
		1:  # Word + Suffix: Standalone word + suffix
			return _generate_word_suffix_name()
		2:  # Compound: Two syllables or word + syllable
			return _generate_compound_name()
	
	return "Unknown"

## Generate name from syllables
func _generate_syllable_name() -> String:
	var prefix = prefixes[randi() % prefixes.size()]
	var middle = ""
	var suffix = suffixes[randi() % suffixes.size()]
	
	# Sometimes add a middle syllable
	if randi() % 2 == 0:
		middle = middles[randi() % middles.size()]
	
	return prefix + middle + suffix

## Generate name from word + suffix
func _generate_word_suffix_name() -> String:
	var word = standalone_words[randi() % standalone_words.size()]
	var suffix = standalone_suffixes[randi() % standalone_suffixes.size()]
	
	return word + " " + suffix.capitalize()

## Generate compound name
func _generate_compound_name() -> String:
	if randi() % 2 == 0:
		# Two syllables
		var first = prefixes[randi() % prefixes.size()]
		var second = prefixes[randi() % prefixes.size()]
		var middle = middles[randi() % middles.size()]
		var suffix = suffixes[randi() % suffixes.size()]
		return first + middle + second + suffix
	else:
		# Word + syllable
		var word = standalone_words[randi() % standalone_words.size()]
		var prefix = prefixes[randi() % prefixes.size()]
		var suffix = suffixes[randi() % suffixes.size()]
		return word + prefix + suffix
