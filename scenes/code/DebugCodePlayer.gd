extends Node
class_name DebugCodePlayer

@export var player : Player

func play(code: String) -> void:
    var parsed_code = parse(code)
    # Here you would implement the logic to execute the parsed code
    print("Executing code:", parsed_code)

func parse(data: String) -> Dictionary:
    var result := {}
    var lines := data.split("\n", false)
    
    for line in lines:
        line = line.strip_edges()
        if line == "" or line.begins_with("#"):
            continue  # Skip empty lines and comments
    return result