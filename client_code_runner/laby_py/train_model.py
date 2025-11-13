import gymnasium as gym
import time
import torch as th
import torch.nn as nn
from stable_baselines3 import DQN
from stable_baselines3.common.torch_layers import BaseFeaturesExtractor
from stable_baselines3.common.env_checker import check_env
from maze_env import MazeEnv

class CustomCnnExtractor(BaseFeaturesExtractor):
    """
    :param observation_space: The observation space of the environment
    :param features_dim: Number of features to output.
    """
    def __init__(self, observation_space: gym.spaces.Box, features_dim: int = 128):
        super().__init__(observation_space, features_dim)
        # Wir nehmen an, dass die Eingabe die Form (Kanäle, Höhe, Breite) hat.
        # Der VecTransposeImage Wrapper von SB3 kümmert sich darum.
        n_input_channels = observation_space.shape[0]
        self.cnn = nn.Sequential(
            nn.Conv2d(n_input_channels, 16, kernel_size=3, stride=1, padding=1),
            nn.ReLU(),
            nn.Conv2d(16, 32, kernel_size=3, stride=2, padding=1), # Stride 2 reduziert die Größe
            nn.ReLU(),
            nn.Conv2d(32, 64, kernel_size=3, stride=2, padding=1), # Stride 2 reduziert die Größe
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
    env = MazeEnv(maze_width=37, maze_height=19, render_mode=None)

    # 2. Umgebung überprüfen
    print("Überprüfe die Umgebung...")
    check_env(env)
    print("Umgebungs-Check erfolgreich!")

    # Policy-Argumente mit unserem benutzerdefinierten Netzwerk
    policy_kwargs = dict(
        features_extractor_class=CustomCnnExtractor,
        features_extractor_kwargs=dict(features_dim=128), # Dimension des Feature-Vektors
    )

    # 3. Modell erstellen
    model = DQN(
        "CnnPolicy",
        env,
        policy_kwargs=policy_kwargs,
        verbose=1,
        tensorboard_log="./maze_tensorboard/",
        learning_rate=0.0005,
        buffer_size=50000,
        learning_starts=1000,
        batch_size=64, # Größere Batch-Größe kann stabilisieren
        gamma=0.99,
        exploration_fraction=0.8, # Länger explorieren
        exploration_final_eps=0.05,
        train_freq=(4, "step"), # Seltener trainieren
        gradient_steps=1,
    )

    # 4. Modell trainieren
    TRAIN_STEPS = 30000
    print(f"\n--- Beginne Training für {TRAIN_STEPS} Schritte... ---")
    model.learn(total_timesteps=TRAIN_STEPS, log_interval=4)
    print("--- Training abgeschlossen. ---")

    # 5. Modell speichern
    MODEL_PATH = "dqn_maze_model.zip"
    model.save(MODEL_PATH)
    print(f"Modell gespeichert unter: {MODEL_PATH}")

    # --- Evaluierung des trainierten Modells ---
    print("\n--- Beginne Evaluierung des trainierten Modells... ---")

    eval_env = MazeEnv(maze_width=37, maze_height=19, render_mode='human')

    del model
    model = DQN.load(MODEL_PATH)

    obs, info = eval_env.reset()

    import os
    os.system('cls' if os.name == 'nt' else 'clear')

    for i in range(eval_env._max_steps):
        action, _states = model.predict(obs, deterministic=True)
        obs, reward, terminated, truncated, info = eval_env.step(action)

        time.sleep(0.1)

        if terminated or truncated:
            if terminated:
                print("\nZiel erreicht!")
            else:
                print("\nMaximale Anzahl an Schritten erreicht.")
            break

    eval_env.close()
    print("--- Evaluierung abgeschlossen. ---")
