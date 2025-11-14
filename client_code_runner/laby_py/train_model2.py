import gymnasium as gym
import time
import torch as th
import torch.nn as nn
import random
from stable_baselines3 import DQN
from stable_baselines3.common.torch_layers import BaseFeaturesExtractor
from stable_baselines3.common.env_checker import check_env
from maze_env import MazeEnv

# Eine einfachere CNN-Architektur für schnelleres Lernen in kurzen Trainingsläufen
class CustomCnnExtractor(BaseFeaturesExtractor):
    """
    :param observation_space: The observation space of the environment
    :param features_dim: Number of features to output.
    """
    def __init__(self, observation_space: gym.spaces.Box, features_dim: int = 128):
        super().__init__(observation_space, features_dim)
        n_input_channels = observation_space.shape[0]
        self.cnn = nn.Sequential(
            nn.Conv2d(n_input_channels, 16, kernel_size=3, stride=1, padding=1),
            nn.ReLU(),
            nn.Conv2d(16, 32, kernel_size=3, stride=2, padding=1),
            nn.ReLU(),
            nn.Flatten(),
        )

        # Berechne die Form nach den Faltungsschichten durch einen Forward-Pass
        with th.no_grad():
            sample_input = th.as_tensor(observation_space.sample()[None]).float()
            n_flatten = self.cnn(sample_input).shape[1]

        self.linear = nn.Sequential(nn.Linear(n_flatten, features_dim), nn.ReLU())

    def forward(self, observations: th.Tensor) -> th.Tensor:
        return self.linear(self.cnn(observations))


# --- Haupt-Skript ---
if __name__ == "__main__":
    # 1. Umgebung erstellen
    SEED = 42
    random.seed(SEED)
    env = MazeEnv(maze_width=37, maze_height=19, render_mode=None)
    env.reset()

    # 2. Umgebung überprüfen
    print("Überprüfe die Umgebung...")
    check_env(env)
    print("Umgebungs-Check erfolgreich!")

    # Neue, einfachere Policy-Argumente
    policy_kwargs = dict(
        features_extractor_class=CustomCnnExtractor,
        features_extractor_kwargs=dict(features_dim=128),
        net_arch=[128] # Einfacherer Q-Network-Kopf
    )

    # 3. Modell mit aggressiven Hyperparametern für sehr kurzes Training
    model = DQN(
        "CnnPolicy",
        env,
        policy_kwargs=policy_kwargs,
        verbose=1,
        tensorboard_log="./maze_tensorboard/",
        learning_rate=0.001,            # Höhere Lernrate für schnellen Fortschritt
        buffer_size=20000,              # Kleinerer Buffer
        learning_starts=1000,           # Sehr früher Lernstart
        batch_size=64,
        gamma=0.99,
        exploration_fraction=0.8,       # Extrem hohe Exploration
        exploration_final_eps=0.1,      # Höherer finaler Epsilon-Wert
        train_freq=(4, "step"),
        gradient_steps=1,
        target_update_interval=250,     # Sehr häufiges Update des Target-Netzwerks
        seed=SEED
    )

    # 4. Modell trainieren mit 15000 Schritten
    TRAIN_STEPS = 15000
    print(f"\n--- Beginne Training für {TRAIN_STEPS} Schritte... ---")
    model.learn(total_timesteps=TRAIN_STEPS, log_interval=10)
    print("--- Training abgeschlossen. ---")

    # 5. Modell speichern
    MODEL_PATH = "dqn_maze_model_v4.zip" # Neuer Name für das neue Modell
    model.save(MODEL_PATH)
    print(f"Modell gespeichert unter: {MODEL_PATH}")

    # --- Evaluierung des trainierten Modells ---
    print("\n--- Beginne Evaluierung des trainierten Modells... ---")

    eval_env = MazeEnv(maze_width=37, maze_height=19, render_mode='human')

    del model
    model = DQN.load(MODEL_PATH)

    obs, info = eval_env.reset(seed=SEED)
    
    agent_path = [(info['agent_pos']['x'], info['agent_pos']['y'])]
    
    import os
    os.system('cls' if os.name == 'nt' else 'clear')
    print("Starte Vorhersage... Der Agent bewegt sich durch das Labyrinth.")

    for i in range(eval_env._max_steps):
        action, _states = model.predict(obs, deterministic=True)
        
        obs, reward, terminated, truncated, info = eval_env.step(action)
        
        pos_tuple = (info['agent_pos']['x'], info['agent_pos']['y'])
        if agent_path[-1] != pos_tuple:
            agent_path.append(pos_tuple)

        time.sleep(0.05)

        if terminated or truncated:
            print("\nEpisode beendet.")
            if terminated:
                print("Status: Ziel erreicht!")
            else:
                print("Status: Maximale Anzahl an Schritten erreicht.")
            break
    
    eval_env.close()

    print("\n--- Visuelle Darstellung des vom Agenten gegangenen Pfades ---")
    
    final_maze_vis = eval_env._generator.visuell_darstellen(pfad=agent_path)
    
    for line in final_maze_vis:
        print(line)
        
    print(f"\nDer Agent hat {len(agent_path) - 1} Schritte gemacht.")
    print("--- Evaluierung abgeschlossen. ---")
