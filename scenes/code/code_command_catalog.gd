extends RefCounted
class_name CodeCommandCatalog

const FUNCTION_TEMPLATE_ID: String = "__new_function__"
const COMBO_DEFINITIONS: Array[ComboDefinition] = [
	preload("res://assets/data/combos/earthquake.tres"),
	preload("res://assets/data/combos/sound_wave.tres"),
	preload("res://assets/data/combos/double_strike.tres"),
	preload("res://assets/data/combos/cross_explosion.tres"),
	preload("res://assets/data/combos/whirlwind.tres"),
]


static func get_entries(locale: String = "de") -> Array[Dictionary]:
	if locale == "en":
		return _get_english_entries()
	return _get_german_entries()


static func get_examples(locale: String = "de") -> Array[Dictionary]:
	if locale == "en":
		return [
			{
				"name": "First steps",
				"code": "repeat 3 times\n    right\nend\nrepeat 3 times\n    left\nend\nattack",
			},
		]
	return [
		{
			"name": "Hin und zurück",
			"code": "schritte = 3\nwiederhole schritte mal\n    rechts\nende\nwiederhole schritte mal\n    links\nende\nsage Wieder am Start",
			"description": "Definiert schritte und läuft dieselbe Strecke hin und zurück.",
		},
		{
			"name": "Sicher trinken",
			"code": "wasser_abstand = abstand zu wasser\nwenn wasser_abstand kleiner 3\n    wenn wasser rechts\n        sage Wasser gefunden\n        rechts\n        trinke\n        links\n    ende\nende",
			"description": "Prüft Abstand und Richtung, richtet sich zum Wasser aus und trinkt.",
		},
		{
			"name": "Patrouille mit Angriff",
			"code": "wiederhole 2 mal\n    links\n    wenn gegner links\n        attacke\n    ende\n    rechts\n    wenn gegner rechts\n        attacke\n    ende\nende",
			"description": "Patrouilliert links und rechts und greift erkannte Gegner an.",
		},
		{
			"name": "Entscheidung mit Sonst",
			"code": "wenn gegner links\n    links\n    attacke\nsonst wenn gegner rechts\n    rechts\n    attacke\nsonst\n    sage Kein Gegner neben mir\nende",
			"description": "Prüft mehrere Bedingungen der Reihe nach und führt nur den ersten passenden Zweig aus.",
		},
		{
			"name": "Kleine Verteidigung",
			"code": "links\nbaue mauer links\nrechts\noben\nbaue turm oben\nunten",
			"description": "Bewegt sich zwischen zwei Baupositionen und errichtet Mauer und Turm.",
		},
		{
			"name": "Baurezept: Lagerfeuer",
			"code": "baue mauer links\ndroppe item 1 links\nsage Lagerfeuer gebaut",
			"description": "Baut links eine Mauer und legt eine Fackel aus Slot 1 auf dasselbe Tile. Daraus entsteht automatisch ein Lagerfeuer.",
		},
		{
			"name": "Baurezept: Kanone",
			"code": "baue mauer links\ndroppe item 3 links\ndroppe item 2 links\ndroppe item 1 links\nsage Kanone gebaut",
			"description": "Lege Fackel in Slot 1, Eisen in Slot 2 und Kohle in Slot 3. Durch die rückwärts geleerten Slots landet die Fackel zuletzt auf der Mauer und das vollständige Rezept erzeugt direkt eine Kanone.",
		},
		{
			"name": "Upgrade: Lagerfeuer zu Kanone",
			"code": "baue mauer links\ndroppe item 3 links\ndroppe item 2 links\ndroppe item 1 links\nsage Lagerfeuer aufgerüstet",
			"description": "Lege Eisen in Slot 1, Kohle in Slot 2 und Fackel in Slot 3. Die Fackel erzeugt zuerst das Lagerfeuer; Kohle und Eisen rüsten es danach zur Kanone auf.",
		},
		{
			"name": "Upgrade: Magiekanone",
			"code": "baue mauer links\ndroppe item 3 links\ndroppe item 2 links\ndroppe item 1 links\ndroppe item 1 links\nsage Magiekanone bereit",
			"description": "Lege Fackel in Slot 1, Eisen in Slot 2, Kohle in Slot 3 und einen magischen Stein in Slot 4. Die ersten drei Drops bauen die Kanone; der danach auf Slot 1 gerückte magische Stein verbessert sie zur Magiekanone.",
		},
		{
			"name": "Baurezept: Sprung-Tile",
			"code": "baue mauer links\ndroppe item 2 links\ndroppe item 1 links\nlinks\nsage Abflug",
			"description": "Lege magisches Holz in Slot 1 und Harz in Slot 2. Beide Items verwandeln die Mauer in ein Sprung-Tile; beim Betreten schleudert es die Figur in Blickrichtung.",
		},
		{
			"name": "Baurezept: Fallgrube",
			"code": "baue mauer links\ndroppe item 2 links\ndroppe item 1 links\nsage Fallgrube bereit",
			"description": "Lege Speer in Slot 1 und magisches Holz in Slot 2. Die Fallgrube verletzt Spieler, Tiere und Gegner beim Betreten, bleibt aber begehbar.",
		},
		{
			"name": "Baurezept: Schildmauer",
			"code": "baue mauer links\ndroppe item 2 links\ndroppe item 1 links\nsage Schild aktiv",
			"description": "Lege Eisen in Slot 1 und magischen Stein in Slot 2. Die Schildmauer halbiert Schaden an direkt benachbarten Gebäuden.",
		},
		{
			"name": "Upgrade: Kochstelle",
			"code": "baue mauer links\ndroppe item 1 links\ndroppe item 1 links\nsage Essen wird gekocht",
			"description": "Lege Fackel in Slot 1 und Nahrung in Slot 2. Der erste Drop baut das Lagerfeuer; durch das Nachrücken liegt Nahrung danach in Slot 1 und baut die Kochstelle. Weitere Nahrung wird zu gekochter Nahrung.",
		},
		{
			"name": "Teleport-Paar",
			"code": "baue mauer links\ndroppe item 2 links\ndroppe item 1 links\ndroppe item 1 links\nrechts\nrechts\nbaue mauer rechts\ndroppe item 2 rechts\ndroppe item 1 rechts\ndroppe item 1 rechts\nsage Teleporter verbunden",
			"description": "Baue nacheinander zwei Sprung-Tiles aus magischem Holz und Harz und verbessere jedes mit einem magischen Stein. Teleport-Tiles desselben Erbauers werden paarweise verbunden.",
		},
		{
			"name": "Upgrade: Feuerkanone",
			"code": "baue mauer links\ndroppe item 3 links\ndroppe item 2 links\ndroppe item 1 links\ndroppe item 2 links\ndroppe item 1 links\nsage Feuerkanone bereit",
			"description": "Baue zuerst mit Fackel, Eisen und Kohle eine Kanone. Lege danach eine weitere Fackel und Kohle auf dieselbe Kanone, um Brennschaden freizuschalten.",
		},
		{
			"name": "Baurezept: Sensorturm",
			"code": "baue mauer links\ndroppe item 1 links\nsage Sensor erweitert",
			"description": "Lege eine Kristallscherbe in Slot 1 auf die Mauer. Der Turm erweitert den Sensor des Erbauers um fünf Tiles; die Sensoransicht markiert dadurch weiter entfernte Gegner.",
		},
		{
			"name": "Baurezept: Heilbrunnen",
			"code": "baue mauer links\ndroppe item 2 links\ndroppe item 1 links\nsage Heilung aktiv",
			"description": "Lege magisches Holz in Slot 1 und magischen Stein in Slot 2. Spieler im Umkreis erhalten jede Sekunde Leben und Mana.",
		},
		{
			"name": "Solange: drei Schritte",
			"code": "schritte = 0\nsolange schritte kleiner 3\n    rechts\n    schritte = schritte + 1\nende",
			"description": "Wiederholt den Block, solange der Vergleich wahr ist.",
		},
		{
			"name": "Wiederhole bis zum Ziel",
			"code": "schritte = 0\nwiederhole bis schritte gleich 3\n    links\n    schritte = schritte + 1\nende",
			"description": "Wiederholt den Block, bis die Bedingung wahr wird.",
		},
		{
			"name": "Für: Runden zählen",
			"code": "für runde von 1 bis 3\n    sage runde\n    rechts\n    links\nende",
			"description": "Zählt einschließlich von 1 bis 3 und speichert die aktuelle Zahl in runde.",
		},
		{
			"name": "Für jedes Item",
			"code": "für jedes item im inventar\n    sage item\nende",
			"description": "Durchläuft einen Snapshot aller vorhandenen Item-Arten im Inventar.",
		},
		{
			"name": "Für jedes Sensor-Objekt",
			"code": "für jedes objekt im sensor\n    sage objekt\nende",
			"description": "Durchläuft die Tile-Koordinaten aller aktuell erkannten Objekte.",
		},
		{
			"name": "Immer mit sicherem Ende",
			"code": "runden = 0\nimmer\n    links\n    rechts\n    runden = runden + 1\n    wenn runden gleich 3\n        verlasse\n    ende\nende",
			"description": "Läuft dauerhaft, wird hier aber nach drei Runden bewusst verlassen.",
		},
		{
			"name": "Verlasse eine Schleife",
			"code": "für schritt von 1 bis 10\n    wenn schritt größer 3\n        verlasse\n    ende\n    rechts\nende",
			"description": "Beendet nur die innerste Schleife, sobald schritt größer als 3 ist.",
		},
		{
			"name": "Weiter zum nächsten Durchlauf",
			"code": "für schritt von 1 bis 5\n    wenn schritt gleich 3\n        weiter\n    ende\n    sage schritt\nende",
			"description": "Überspringt bei 3 den restlichen Schleifenblock und fährt mit 4 fort.",
		},
		{
			"name": "Mauer in C-Form",
			"code": "seitenlaenge = 2\nbaue mauer links\nwiederhole seitenlaenge mal\n    oben\n    baue mauer links\nende\nunten\nbaue mauer oben\nrechts\nbaue mauer oben\nwiederhole seitenlaenge mal\n    unten\nende\nbaue mauer oben\nlinks\nbaue mauer oben\nsage C-Mauer fertig",
			"description": "Baut aus sieben Mauer-Tiles ein C mit einer offenen rechten Seite.",
		},
		_combo_example(COMBO_DEFINITIONS[0]),
		_combo_example(COMBO_DEFINITIONS[1]),
		_combo_example(COMBO_DEFINITIONS[2]),
		_combo_example(COMBO_DEFINITIONS[3]),
		_combo_example(COMBO_DEFINITIONS[4]),
		{
			"name": "Variable Laufstrecke",
			"code": "schritte = 2\nrunden = 2\nwiederhole runden mal\n    wiederhole schritte mal\n        rechts\n    ende\n    wiederhole schritte mal\n        links\n    ende\nende\nsage Training beendet",
			"description": "Verwendet zwei Variablen und verschachtelte Schleifen für mehrere Runden.",
		},
		{
			"name": "Mana beobachten",
			"code": "mein_mana = spieler mana\nwenn mein_mana größer 30\n    sage Genug Mana für eine Combo\n    combo links attacke rechts attacke\nende",
			"description": "Liest das aktuelle Mana in eine Variable und setzt eine Combo nur bei genügend Mana ein.",
		},
	]


static func _combo_example(definition: ComboDefinition) -> Dictionary:
	return {
		"name": "Combo: %s" % definition.display_name,
		"code": definition.code_command,
		"description": definition.description,
	}


static func get_function_templates(locale: String = "de") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in get_entries(locale):
		if bool(entry.get("show_in_functions", false)):
			result.append(entry)
	return result


static func get_description(symbol: String, locale: String = "de") -> String:
	var normalized_symbol: String = symbol.strip_edges().to_lower()
	for entry: Dictionary in get_entries(locale):
		var keywords: PackedStringArray = entry.get("keywords", PackedStringArray())
		if normalized_symbol == String(entry.get("trigger", "")) or normalized_symbol in keywords:
			return String(entry.get("description", ""))
	return ""


static func get_highlight_groups(locale: String = "de") -> Dictionary:
	var movement: Array[String] = []
	var actions: Array[String] = []
	var control: Array[String] = []
	var conditions: Array[String] = []
	var values: Array[String] = []
	var functions: Array[String] = []
	var localized_actions: Dictionary = Strings.ACTION_NAMES.get(locale, {})
	for localized_action_value: Variant in localized_actions.keys():
		var localized_action: String = String(localized_action_value)
		var action: String = String(localized_actions[localized_action_value])
		var action_target: Array[String] = actions
		if Strings.direction_map.has(action):
			action_target = movement
		_append_highlight_words(localized_action, action_target)

	var localized_conditions: Dictionary = Strings.CONDITION_NAMES.get(locale, {})
	for condition_value: Variant in localized_conditions.keys():
		_append_highlight_words(String(condition_value), conditions)
	var localized_comparisons: Dictionary = Strings.CONDITION_COMPARISON_NAMES.get(locale, {})
	for comparison_value: Variant in localized_comparisons.keys():
		_append_highlight_words(String(comparison_value), conditions)
	_append_highlight_words(
		String(Strings.CONDITION_DISTANCE_KEYWORDS.get(locale, "")),
		conditions
	)
	_append_highlight_words("zu" if locale == "de" else "to", conditions)

	var localized_player_stats: Dictionary = Strings.PLAYER_STAT_NAMES.get(locale, {})
	for stat_value: Variant in localized_player_stats.keys():
		_append_highlight_words(String(stat_value), values)
	_append_highlight_words("spieler" if locale == "de" else "player", values)
	var localized_buildings: Dictionary = Strings.BUILDING_NAMES.get(locale, {})
	for building_value: Variant in localized_buildings.keys():
		_append_highlight_words(String(building_value), values)
	_append_highlight_words("grass water", values)

	if locale == "de":
		control.append_array([
			"wenn", "sonst", "sont", "wiederhole", "mal", "solange", "bis",
			"für", "jedes", "von", "im", "inventar", "sensor", "immer",
			"verlasse", "weiter", "ende",
		])
	else:
		control.append_array([
			"if", "else", "repeat", "times", "while", "until", "for", "each",
			"from", "to", "in", "inventory", "sensor", "forever", "break",
			"continue", "end",
		])
	functions.append(Strings.KEYWORD_FUNC)
	functions.append(Strings.KEYWORD_END_FUNC)
	return {
		"movement": movement,
		"action": actions,
		"control": control,
		"condition": conditions,
		"value": values,
		"function": functions,
	}


static func _append_highlight_words(text: String, target: Array[String]) -> void:
	for word: String in text.to_lower().split(" ", false):
		if not word.is_empty() and word not in target:
			target.append(word)


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
		_entry("droppe", "droppe item 1 links", "Legt ein Item aus dem angegebenen Inventar-Slot bevorzugt in der gewählten Richtung ab. Die Richtung ist optional.", ["droppe", "item"]),
		_entry("baue", "baue mauer links", "Baut Mauer oder Turm auf einem freien Nachbar-Tile.", ["baue"]),
		_entry("male", "male grass rechts", "Ändert ein angrenzendes Terrain-Tile.", ["male"]),
		_entry("combo", "combo links attacke rechts attacke", "Führt eine bekannte Combo aus und verbraucht Mana.", ["combo"]),
		_entry(
			"variable =",
			"schritte = 3",
			"Speichert eine Zahl, einen Text, eine andere Variable oder einen berechneten Wert.",
			["spieler", "abstand", "zu"],
			"control",
			true,
			"Variable"
		),
		_entry(
			"spielerwert =",
			"mein_mana = spieler mana",
			"Liest Mana, Leben, Wasser oder Essen des Players in eine Variable.",
			["spieler", "mana", "leben", "wasser", "essen"],
			"control",
			true,
			"Spielerwert"
		),
		_entry(
			"wiederhole",
			"wiederhole 3 mal\n    \nende",
			"Wiederholt den eingerückten Block mit einer Zahl oder ganzzahligen Variable.",
			["wiederhole", "mal", "ende"],
			"control",
			true,
			"Schleife: wiederhole"
		),
		_entry(
			"solange",
			"solange schritte kleiner 3\n    \nende",
			"Wiederholt den Block, solange dieselbe Art Bedingung wie bei 'wenn' wahr ist.",
			["solange", "kleiner", "größer", "gleich", "ende"],
			"control",
			true,
			"Schleife: solange"
		),
		_entry(
			"wiederhole bis",
			"wiederhole bis schritte gleich 3\n    \nende",
			"Wiederholt den Block, solange die Bedingung noch nicht wahr ist.",
			["wiederhole", "bis", "kleiner", "größer", "gleich", "ende"],
			"control",
			true,
			"Schleife: wiederhole bis"
		),
		_entry(
			"für",
			"für schritt von 1 bis 5\n    \nende",
			"Zählt inklusive von einem Startwert bis zu einem Endwert; auch rückwärts.",
			["für", "von", "bis", "ende"],
			"control",
			true,
			"Schleife: für"
		),
		_entry(
			"für jedes inventar",
			"für jedes item im inventar\n    sage item\nende",
			"Durchläuft die beim Schleifenstart vorhandenen Item-Arten im Inventar.",
			["für", "jedes", "item", "im", "inventar", "ende"],
			"control",
			true,
			"Schleife: Inventar"
		),
		_entry(
			"für jedes sensor",
			"für jedes objekt im sensor\n    sage objekt\nende",
			"Durchläuft erkannte Objekt-Tiles. Möglich sind objekt, item, tier, gegner, wasser und ziel.",
			["für", "jedes", "im", "sensor", "objekt", "item", "tier", "gegner", "wasser", "ziel", "ende"],
			"control",
			true,
			"Schleife: Sensor"
		),
		_entry(
			"immer",
			"immer\n    \nende",
			"Wiederholt einen Block bis Stopp, Laufzeitlimit oder 'verlasse'.",
			["immer", "ende"],
			"control",
			true,
			"Schleife: immer"
		),
		_entry(
			"verlasse",
			"verlasse",
			"Beendet sofort die innerste Schleife.",
			["verlasse"],
			"control",
			true,
			"Schleifensteuerung: verlasse"
		),
		_entry(
			"weiter",
			"weiter",
			"Überspringt den restlichen Block und beginnt den nächsten Durchlauf der innersten Schleife.",
			["weiter"],
			"control",
			true,
			"Schleifensteuerung: weiter"
		),
		_entry(
			"wenn",
			"wenn gegner rechts\n    \nende",
			"Prüft eine Richtung oder den Abstand zum nächsten sichtbaren Ziel.",
			[
				"wenn", "ende", "gegner", "tier", "objekt", "wasser", "frei", "ziel",
				"abstand", "kleiner", "größer", "gleich",
			],
			"control",
			true,
			"Bedingung: wenn"
		),
		_entry(
			"wenn abstand",
			"wenn wasser abstand kleiner 3\n    \nende",
			"Vergleicht den Abstand zum nächsten sichtbaren Ziel in Tiles.",
			["wenn", "ende", "abstand", "kleiner", "größer", "gleich"],
			"control",
			true,
			"Bedingung: Abstand"
		),
		_entry(
			"sonst wenn",
			"wenn gegner rechts\n    \nsonst wenn gegner links\n    \nsonst\n    \nende",
			"Prüft eine weitere vollständige Wenn-Bedingung. Auch 'sont gegner links' ist als kurze Schreibweise erlaubt. Ein abschließendes 'sonst' fängt alle übrigen Fälle ab.",
			["sonst", "sont"],
			"control",
			true,
			"Bedingung: sonst wenn"
		),
		_entry(
			"func",
			FUNCTION_TEMPLATE_ID,
			"Öffnet den Tab für einen wiederverwendbaren Befehlsblock.",
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
		_entry("drop item", "drop item 1 left", "Drops one item from an inventory slot, preferably in the optional direction.", ["drop", "item"]),
		_entry("build", "build wall left", "Builds on a free adjacent tile.", ["build"]),
		_entry("combo", "combo left attack right attack", "Executes a known mana combo.", ["combo"]),
		_entry(
			"repeat",
			"repeat 3 times\n    \nend",
			"Repeats a finite block.",
			["repeat", "times", "end"],
			"control",
			true,
			"Loop: repeat"
		),
		_entry(
			"if",
			"if enemy right\n    \nend",
			"Checks a direction or the distance to the nearest visible target.",
			["if", "end", "distance", "less", "greater", "equal"],
			"control",
			true,
			"Condition: if"
		),
		_entry(
			"if distance",
			"if water distance less 3\n    \nend",
			"Compares the tile distance to the nearest visible target.",
			["if", "end", "distance", "less", "greater", "equal"],
			"control",
			true,
			"Condition: distance"
		),
		_entry(
			"else if",
			"if enemy right\n    \nelse if enemy left\n    \nelse\n    \nend",
			"Checks another full condition; a final else handles every remaining case.",
			["else"],
			"control",
			true,
			"Condition: else if"
		),
		_entry("func", FUNCTION_TEMPLATE_ID, "Opens the tab for reusable function blocks.", ["func"], "function"),
	]


static func _entry(
		trigger: String,
		insert_text: String,
		description: String,
		keywords: Array[String],
		group: String = "movement",
		show_in_functions: bool = false,
		function_label: String = ""
	) -> Dictionary:
	return {
		"trigger": trigger,
		"insert_text": insert_text,
		"description": description,
		"keywords": PackedStringArray(keywords),
		"group": group,
		"show_in_functions": show_in_functions,
		"function_label": function_label,
	}
