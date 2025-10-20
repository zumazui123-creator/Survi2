
import torch as th

# from stable_baselines3 import PPO
import stable_baselines3 as stb
from ki import GodotEnv
from ki import StepLogger

def init_model():

	policy_kwargs = dict(net_arch=[8])


	env = GodotEnv()
	logger_callback = StepLogger()
	# model = stb.DQN(
	# 	"MlpPolicy",
	#     env,                 # deine Umgebung, z.B. GodotEnv()
	#     learning_rate=0.0006,  # Lernrate (kann auch eine Funktion sein)
	# 	batch_size=128,
	# 	buffer_size=50000,
	# 	learning_starts=0,
	# 	policy_kwargs=dict(net_arch=[256, 256]),
	# 	gamma=0.99,
	# 	target_update_interval=256,
	# 	train_freq=1,
	# 	gradient_steps=-1,
	# 	exploration_fraction=0.12,
	# 	exploration_final_eps=0.1,
	# 	n_steps=15
	# )
	#
	model = stb.PPO(
    "MlpPolicy",  # oder Custom CNN wenn nötig
    env,
    learning_rate=0.0006,
    n_steps=1024,
    batch_size=256,
    n_epochs=8,
    gamma=0.99,
    gae_lambda=0.95,
    clip_range=0.2,
    ent_coef=0.10,
    vf_coef=0.5,
    max_grad_norm=0.5,
    policy_kwargs=dict(
        net_arch=[512, 512],
    ),
    verbose=1,
)
	# model = PPO(
	# 	"MlpPolicy",
	#     env,                 # deine Umgebung, z.B. GodotEnv()
	#     learning_rate=3e-4,  # Lernrate (kann auch eine Funktion sein)
	#     n_steps=2048*16,        # Anzahl der Schritte pro Rollout
	#     batch_size=64,       # Minibatch-Größe für Updates
	#     n_epochs=10,         # Wie oft das Netzwerk pro Rollout aktualisiert wird
	#     gamma=0.99,          # Diskontierungsfaktor
	#     gae_lambda=0.95,     # GAE-Lambda für die Vorteilsschätzung
	#     clip_range=0.2,      # Clipping für die Policy-Updates
	#     ent_coef=0.0,        # Entropie-Koeffizient (fördert Exploration)
	#     vf_coef=0.5,         # Value-Funktion-Verlust-Koeffizient
	#     max_grad_norm=0.5,   # Gradienten-Clipping
	#     use_sde=False,       # State Dependent Exploration
	#     sde_sample_freq=-1,  # Sampling-Frequenz für SDE
	#     verbose=2,           # Ausgabe-Level (0, 1 oder 2)
	#     seed=42,           # Zufalls-Seed
	# 	policy_kwargs=policy_kwargs,
	# )

	model_name = "trained_model_ppo"
	try:
		model.load(model_name)
	except Exception as e:
		# model.load(model_name+"2")
		print(f"⚠️ Error in loading trained model: {e}")

	train_model = model.learn(total_timesteps=45000, callback=logger_callback, progress_bar=True)
	obs, info = env.reset()
	print("Initial Obs:", obs)

	try:
		train_model.save(model_name)
	except Exception as e:
		train_model.save(model_name+"2")
		print(f"⚠️ Error in save trained model: {e}")



	env.close()
