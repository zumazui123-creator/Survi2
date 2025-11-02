import numpy as np
import d3rlpy
from d3rlpy.algos import DQNConfig  # Beispiel für diskrete Aktionen
from d3rlpy.dataset import create_fifo_replay_buffer
from d3rlpy.algos import ConstantEpsilonGreedy
from ki import GodotEnv
# from godotEnv import GodotEnv

def train_d3rlpy_online():
    env = GodotEnv()
    # ggf. ein Evaluations-Env mit gleicher Konfiguration:
    # eval_env = GodotEnv(server_url="ws://localhost:8765", timeout=2.0)

    # Algorithmus konfigurieren
    algo = DQNConfig(
        batch_size=64,
        learning_rate=1e-4,
        target_update_interval=1000,
    ).create()  # erzeugt DQN-Agenten :contentReference[oaicite:4]{index=4}

    # Replay‐Buffer erstellen
    buffer = create_fifo_replay_buffer(
        limit=100000,
        env=env
    )

    explorer = ConstantEpsilonGreedy(epsilon=0.3)
    # Training online
    algo.fit_online(
        env=env,
        buffer=buffer,
        explorer=explorer,
        # eval_env=eval_env,
        n_steps=50000,  # Beispielwert: 50k Schritte
        n_steps_per_epoch=200,
        update_interval=200,
        update_start_step=1000,
        random_steps=5000
    )

    # Speichern
    # algo.save_model("d3rlpy_model.pt")

    env.close()

if __name__ == "__main__":
	train_d3rlpy_online()
