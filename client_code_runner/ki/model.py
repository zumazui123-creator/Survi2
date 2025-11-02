import stable_baselines3 as stb
from stable_baselines3.common.vec_env import DummyVecEnv
from stable_baselines3 import HerReplayBuffer, SAC, DDPG, TD3

from ki import GodotEnv
from ki import StepLogger
import ki as ki

def init_model():
    ki.init_model_ppo()

	# env = GodotEnv()
	# env = DummyVecEnv([lambda: GodotEnv()])
	# logger_callback = StepLogger()


	# for i in range(0,500):
	# 	print(i)
	# 	train_model = model.learn(total_timesteps=200, callback=logger_callback, progress_bar=True)
	# 	# obs, info = env.reset()
	# 	obs  = env.reset()
	# 	print("Initial Obs:", obs)



	# env.close()
