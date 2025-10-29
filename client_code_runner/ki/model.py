# from stable_baselines3 import PPO
import stable_baselines3 as stb
from ki import GodotEnv
from ki import StepLogger

def init_model():

	env = GodotEnv()
	logger_callback = StepLogger()
	
	model = stb.PPO(
    "MlpPolicy",  # oder Custom CNN wenn nötig
    env,
    learning_rate=0.0006,
    n_steps=100,
    batch_size=25,
    n_epochs=1000,
    # gamma=0.99,
    # gae_lambda=0.95,
    # clip_range=0.2,
    # ent_coef=0.10,
    # vf_coef=0.5,
    # max_grad_norm=0.5,
    # policy_kwargs=dict(
    #     net_arch=[512, 512],
    # ),
    verbose=1,
)

	model_name = "trained_model_ppo"
	try:
		model.load(model_name)
	except Exception as e:
		# model.load(model_name+"2")
		print(f"⚠️ Error in loading trained model: {e}")

	train_model = model.learn(total_timesteps=4500, callback=logger_callback, progress_bar=True)
	obs, info = env.reset()
	print("Initial Obs:", obs)

	try:
		train_model.save(model_name)
	except Exception as e:
		train_model.save(model_name+"2")
		print(f"⚠️ Error in save trained model: {e}")



	env.close()
