import gymnasium as gym
from stable_baselines3 import PPO
from stable_baselines3.common.callbacks import BaseCallback
import torch
import torch.nn as nn
import matplotlib.pyplot as plt
import networkx as nx
import torch as th

from ki import GodotEnv
from ki import StepLogger


env = GodotEnv()
logger_callback = StepLogger()


model = PPO(
	"MlpPolicy",
    env,                 # deine Umgebung, z.B. GodotEnv()
    learning_rate=3e-4,  # Lernrate (kann auch eine Funktion sein)
    n_steps=2048,        # Anzahl der Schritte pro Rollout
    batch_size=64,       # Minibatch-Größe für Updates
    n_epochs=10,         # Wie oft das Netzwerk pro Rollout aktualisiert wird
    gamma=0.99,          # Diskontierungsfaktor
    gae_lambda=0.95,     # GAE-Lambda für die Vorteilsschätzung
    clip_range=0.2,      # Clipping für die Policy-Updates
    ent_coef=0.0,        # Entropie-Koeffizient (fördert Exploration)
    vf_coef=0.5,         # Value-Funktion-Verlust-Koeffizient
    max_grad_norm=0.5,   # Gradienten-Clipping
    use_sde=False,       # State Dependent Exploration
    sde_sample_freq=-1,  # Sampling-Frequenz für SDE
    verbose=2,           # Ausgabe-Level (0, 1 oder 2)
    seed=None,           # Zufalls-Seed
)


# Extrahiere das Policy-Netzwerk (den "actor")
# policy_net = model.policy.mlp_extractor.policy_net
# visualize_network(policy_net)

model.learn(total_timesteps=100, callback=logger_callback, progress_bar=True)
obs, info = env.reset()
print("Initial Obs:", obs)



env.close()
