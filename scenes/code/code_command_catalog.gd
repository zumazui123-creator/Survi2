extends RefCounted
class_name CodeCommandCatalog

const FUNCTION_TEMPLATE_ID: String = "__new_function__"


static func get_entries(locale: String = "de") -> Array[Dictionary]:
	if locale == "en":
		return _get_english_entries()
	return _get_german_entries()


static func get_examples(locale: String = "de") -> Array[Dictionary]:
	if locale == "en":
		return [
			{
				"name": "First steps",
				"code": "repeat 3 times\n    right\nend\nattack",
			},
		]
	return [
		{
			"name": "Erste Schritte",
			"code": "wiederhole 3 mal\n    rechts\nende\nattacke",
		},
		{
			"name": "Sicher trinken",
			"code": "wenn wasser rechts\n    rechts\n    trinke\nende",
		},
		{
			"name": "Gegner abwehren",
			"code": "wenn gegner links\n    links\n    attacke\nende",
		},
		{
			"name": "Mauer und Turm",
			"code": "baue mauer links\nbaue turm rechts",
		},
		{
			"name": "Schallwellen-Combo",
			"code": "combo links attacke rechts attacke",
		},
		{
			"name": "Variablen und Wiederholung",
			"code": "schritte = 3\nwiederhole schritte mal\n    rechts\nende\nsage schritte",
		},
		{
			"name": "Wasser suchen",
			"code": "wasser_abstand = abstand zu wasser\nwenn wasser_abstand kleiner 3\n    sage Wasser ist nah\nende",
			"description": "Definiert wasser_abstand, bevor die Variable verwendet wird.",
		},
	]


static func get_description(symbol: String, locale: String = "de") -> String:
	var normalized_symbol: String = symbol.strip_edges().to_lower()
	for entry: Dictionary in get_entries(locale):
		var keywords: PackedStringArray = entry.get("keywords", PackedStringArray())
		if normalized_symbol == String(entry.get("trigger", "")) or normalized_symbol in keywords:
			return String(entry.get("description", ""))
	return ""


static func get_highlight_groups(locale: String = "de") -> Dictionary:
	var movement: Array[String] = []
	var control: Array[String] = []
	var functions: Array[String] = []
	for entry: Dictionary in get_entries(locale):
		var target: Array[String] = movement
		var group: String = String(entry.get("group", "movement"))
		if group == "control":
			target = control
		elif group == "function":
			target = functions
		for keyword: String in entry.get("keywords", PackedStringArray()):
			if keyword not in target:
				target.append(keyword)
	return {
		"movement": movement,
		"control": control,
		"function": functions,
	}


static func _get_german_entries() -> Array[Dictionary]:
	return [
		_entry("links", "links", "Bewegt die Figur ein Tile nach links.", ["links"]),
		_entry("rechts", "rechts", "Bewegt die Figur ein Tile nach rechts.", ["rechts"]),
		_entry("oben", "oben", "Bewegt die Figur ein Tile nach oben.", ["oben"]),
		_entry("unten", "unten", "Bewegt die Figur ein Tile nach unten.", ["unten"]),
		_entry("attacke", "attacke", "Greift das Tile vor den Händen an.", ["attacke"]),
		_entry("trinke", "trinke", "Trinkt, wenn die Hände ein Wasser-Tile berühren.", ["trinke"]),
		_entry("sage", "sage Hallo", "Lässt die Figur den folgenden Text sagen.", ["sage"]),
		_entry("nutze", "nutze item 1", "Benutzt den angegebenen Inventar-Slot.", ["nutze", "item"]),
		_entry("baue", "baue mauer links", "Baut Mauer oder Turm auf einem freien Nachbar-Tile.", ["baue"]),
		_entry("male", "male grass rechts", "Ändert ein angrenzendes Terrain-Tile.", ["male"]),
		_entry("combo", "combo links attacke rechts attacke", "Führt eine bekannte Combo aus und verbraucht Mana.", ["combo"]),
		_entry(
			"variable =",
			"schritte = 3",
			"Speichert eine Zahl, einen Text, eine andere Variable oder einen berechneten Wert.",
			["spieler", "abstand", "zu"],
			"control"
		),
		_entry(
			"spielerwert =",
			"mein_mana = spieler mana",
			"Liest Mana, Leben, Wasser oder Essen des Players in eine Variable.",
			["spieler", "mana", "leben", "wasser", "essen"],
			"control"
		),
		_entry(
			"wiederhole",
			"wiederhole 3 mal\n    \nende",
			"Wiederholt den eingerückten Block mit einer Zahl oder ganzzahligen Variable.",
			["wiederhole", "mal", "ende"],
			"control"
		),
		_entry(
			"wenn",
			"wenn gegner rechts\n    \nende",
			"Prüft eine Richtung oder den Abstand zum nächsten sichtbaren Ziel.",
			[
				"wenn", "ende", "gegner", "tier", "objekt", "wasser", "frei", "ziel",
				"abstand", "kleiner", "größer", "gleich",
			],
			"control"
		),
		_entry(
			"wenn abstand",
			"wenn wasser abstand kleiner 3\n    \nende",
			"Vergleicht den Abstand zum nächsten sichtbaren Ziel in Tiles.",
			["wenn", "ende", "abstand", "kleiner", "größer", "gleich"],
			"control"
		),
		_entry(
			"func",
			FUNCTION_TEMPLATE_ID,
			"Öffnet den Funktionseditor für einen wiederverwendbaren Befehlsblock.",
			["func", "end_func"],
			"function"
		),
	]


static func _get_english_entries() -> Array[Dictionary]:
	return [
		_entry("left", "left", "Moves the player one tile left.", ["left"]),
		_entry("right", "right", "Moves the player one tile right.", ["right"]),
		_entry("up", "up", "Moves the player one tile up.", ["up"]),
		_entry("down", "down", "Moves the player one tile down.", ["down"]),
		_entry("attack", "attack", "Attacks the tile in front of the hands.", ["attack"]),
		_entry("drink", "drink", "Drinks when the hands touch water.", ["drink"]),
		_entry("speak", "speak Hello", "Makes the player say the following text.", ["speak"]),
		_entry("use item", "use item 1", "Uses an inventory slot.", ["use", "item"]),
		_entry("build", "build wall left", "Builds on a free adjacent tile.", ["build"]),
		_entry("combo", "combo left attack right attack", "Executes a known mana combo.", ["combo"]),
		_entry("repeat", "repeat 3 times\n    \nend", "Repeats a finite block.", ["repeat", "times", "end"], "control"),
		_entry(
			"if",
			"if enemy right\n    \nend",
			"Checks a direction or the distance to the nearest visible target.",
			["if", "end", "distance", "less", "greater", "equal"],
			"control"
		),
		_entry(
			"if distance",
			"if water distance less 3\n    \nend",
			"Compares the tile distance to the nearest visible target.",
			["if", "end", "distance", "less", "greater", "equal"],
			"control"
		),
		_entry("func", FUNCTION_TEMPLATE_ID, "Opens the reusable function editor.", ["func"], "function"),
	]


static func _entry(
		trigger: String,
		insert_text: String,
		description: String,
		keywords: Array[String],
		group: String = "movement"
	) -> Dictionary:
	return {
		"trigger": trigger,
		"insert_text": insert_text,
		"description": description,
		"keywords": PackedStringArray(keywords),
		"group": group,
	}
