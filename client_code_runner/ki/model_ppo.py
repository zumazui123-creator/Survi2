
import stable_baselines3 as stb
from stable_baselines3.common.vec_env import DummyVecEnv
from stable_baselines3 import HerReplayBuffer, SAC, DDPG, TD3, DQN

from ki import GodotEnv
from ki import StepLogger

def init_model_ppo():

	# env = GodotEnv()
	env = DummyVecEnv([lambda: GodotEnv()])
	logger_callback = StepLogger()

	model = DQN(
        "MlpPolicy",
        env,
        # learning_rate=1e-4,
        learning_rate=0.6,
        buffer_size=1000,
        learning_starts=100,
        batch_size=32,      # Wichtiger: kleine Batches
        target_update_interval=200,
        train_freq=4,
        gradient_steps=1,
        exploration_fraction=0.1,
        verbose=2
    )
	# model = stb.PPO(
 #        "MlpPolicy",
 #        env,
 #        learning_rate=3e-4,
 #        n_steps=256,        # Sollte durch batch_size teilbar sein
 #        batch_size=64,      # VIEL kleiner - für Mini-Batches
 #        n_epochs=1000,        # Mehr Epochen für bessere Updates
 #        gamma=0.99,
 #        clip_range=0.2,
 #        ent_coef=0.01,      # Leichtes Exploration-Encouragement
 #        verbose=1,
 #    )
# 	model = stb.PPO(
#     "MlpPolicy",  # oder Custom CNN wenn nötig
#     env,
#     learning_rate=0.03,
#     # learning_rate=0.0006,
#     n_steps=500,
#     batch_size=100,
#     n_epochs=1,
#     gamma=0.99,
#     gae_lambda=0.95,
#     clip_range=0.2,
#     ent_coef=0.10,
#     vf_coef=0.5,
#     max_grad_norm=0.5,
#     policy_kwargs=dict(
#         net_arch=[512, 512],
#     ),
#     verbose=1,
# )


	model_name = "trained_model_ppo"
	# try:
	# 	model.load(model_name)
	# except Exception as e:
	# 	# model.load(model_name+"2")
	# 	print(f"⚠️ Error in loading trained model: {e}")

	for i in range(0,2):
		print(i)
		train_model = model.learn(total_timesteps=256, callback=logger_callback, progress_bar=True)
		# obs, info = env.reset()
		obs  = env.reset()
		print("Initial Obs:", obs)

	# try:
	# 	train_model.save(model_name)
	# except Exception as e:
	# 	train_model.save(model_name+"2")
	# 	print(f"⚠️ Error in save trained model: {e}")



	env.close()
