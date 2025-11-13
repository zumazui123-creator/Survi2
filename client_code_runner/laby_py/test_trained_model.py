import gymnasium as gym
import time
import os
from stable_baselines3 import DQN
from maze_env import MazeEnv

# --- Konfiguration ---
MODEL_PATH = "dqn_maze_model.zip"
MAZE_WIDTH = 37
MAZE_HEIGHT = 19

# --- Haupt-Skript zur Evaluierung ---
if __name__ == "__main__":
    # 1. Prüfen, ob das trainierte Modell existiert
    if not os.path.exists(MODEL_PATH):
        print(f"Fehler: Modelldatei nicht gefunden unter '{MODEL_PATH}'")
        print("Bitte führen Sie zuerst das Skript 'train_model.py' aus, um das Modell zu trainieren.")
        exit()

    print(f"Lade trainiertes Modell von '{MODEL_PATH}'...")

    # 2. Umgebung und Modell laden
    eval_env = MazeEnv(maze_width=MAZE_WIDTH, maze_height=MAZE_HEIGHT, render_mode='human')
    model = DQN.load(MODEL_PATH)

    # 3. Evaluierung starten
    obs, info = eval_env.reset()
    
    # Liste zum Speichern des vom Agenten gegangenen Pfades
    agent_path = [(info['agent_pos']['x'], info['agent_pos']['y'])]
    
    # Terminal für eine saubere Anzeige leeren
    os.system('cls' if os.name == 'nt' else 'clear')
    print("Starte Vorhersage... Der Agent bewegt sich durch das Labyrinth.")

    for i in range(eval_env._max_steps):
        # Aktion vom Modell vorhersagen lassen
        action, _states = model.predict(obs, deterministic=True)
        
        # Aktion in der Umgebung ausführen
        obs, reward, terminated, truncated, info = eval_env.step(action)
        
        # Position als Tupel zum Pfad hinzufügen
        pos_tuple = (info['agent_pos']['x'], info['agent_pos']['y'])
        if agent_path[-1] != pos_tuple:
            agent_path.append(pos_tuple)

        # Kurze Pause, um die Bewegung sichtbar zu machen
        time.sleep(0.05)

        if terminated or truncated:
            print("\nEpisode beendet.")
            if terminated:
                print("Status: Ziel erreicht!")
            else:
                print("Status: Maximale Anzahl an Schritten erreicht.")
            break
            
    eval_env.close()

    # 4. Finalen Pfad visualisieren
    print("\n--- Visuelle Darstellung des vom Agenten gegangenen Pfades ---")
    
    # Die Methode aus unserem Labyrinth-Generator wiederverwenden
    final_maze_vis = eval_env._generator.visuell_darstellen(pfad=agent_path)
    
    for line in final_maze_vis:
        print(line)
        
    print(f"\nDer Agent hat {len(agent_path) - 1} Schritte gemacht.")
