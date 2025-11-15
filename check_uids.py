
import sys
import re

def check_uids(tscn_files, resource_map_file):
    resource_map = {}
    with open(resource_map_file, 'r') as f:
        for line in f:
            parts = line.strip().split(',')
            if len(parts) == 2:
                resource_map[parts[0]] = parts[1]

    ext_resource_pattern = re.compile(r'\[ext_resource\s+type="([^"]+)"\s+(?:uid="([^"]+)"\s+)?path="([^"]+)"\s+id="([^"]+)"\]')

    for tscn_file in tscn_files:
        with open(tscn_file, 'r') as f:
            for i, line in enumerate(f, 1):
                match = ext_resource_pattern.match(line)
                if match:
                    res_type, uid, path, res_id = match.groups()
                    if path in resource_map:
                        correct_uid = resource_map[path]
                        if uid is None:
                            print(f"Missing UID in {tscn_file}:{i}: for resource {path}. Correct UID is {correct_uid}")
                        elif uid != correct_uid:
                            print(f"Incorrect UID in {tscn_file}:{i}: for resource {path}. Found {uid}, expected {correct_uid}")

if __name__ == "__main__":
    tscn_files = [
        "/home/ubi/Code/Survi2/scenes/ui/daynight/daynightcycle_ui.tscn",
        "/home/ubi/Code/Survi2/scenes/ui/mainMenu/mainMenu.tscn",
        "/home/ubi/Code/Survi2/scenes/ui/minimap/minimap.tscn",
        "/home/ubi/Code/Survi2/scenes/ui/spawn/spawnPlayer.tscn",
        "/home/ubi/Code/Survi2/scenes/ui/chat/message_box.tscn",
        "/home/ubi/Code/Survi2/scenes/ui/chat/chat_input.tscn",
        "/home/ubi/Code/Survi2/scenes/ui/inventory/inventory_slot.tscn",
        "/home/ubi/Code/Survi2/scenes/ui/inventory/recipe_slot.tscn",
        "/home/ubi/Code/Survi2/scenes/ui/inventory/inventory.tscn",
        "/home/ubi/Code/Survi2/scenes/ui/playersList/player_slot.tscn",
        "/home/ubi/Code/Survi2/scenes/ui/playersList/generalHud.tscn",
        "/home/ubi/Code/Survi2/scenes/mapGen/map.tscn",
        "/home/ubi/Code/Survi2/scenes/attacks/projectile_attack.tscn",
        "/home/ubi/Code/Survi2/scenes/attacks/slash_attack.tscn",
        "/home/ubi/Code/Survi2/scenes/character/equipments/torch.tscn",
        "/home/ubi/Code/Survi2/scenes/character/player.tscn",
        "/home/ubi/Code/Survi2/scenes/animal/animal.tscn",
        "/home/ubi/Code/Survi2/scenes/spawn/object/breakable.tscn",
        "/home/ubi/Code/Survi2/scenes/enemy/enemy.tscn",
        "/home/ubi/Code/Survi2/scenes/main/HUD/EndUI.tscn",
        "/home/ubi/Code/Survi2/scenes/main/HUD/hydration_bar.tscn",
        "/home/ubi/Code/Survi2/scenes/main/main.tscn",
        "/home/ubi/Code/Survi2/scenes/item/pickup.tscn",
        "/home/ubi/Code/Survi2/scenes/game/Game.tscn",
        "/home/ubi/Code/Survi2/client_code_runner/archive/alt_code/code_control.tscn",
        "/home/ubi/Code/Survi2/code_editor.tscn"
    ]
    resource_map_file = "/home/ubi/Code/Survi2/resource_uid_map.csv"
    check_uids(tscn_files, resource_map_file)
