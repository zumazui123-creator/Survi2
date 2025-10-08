from godotEnv import GodotEnv
import gymnasium as gym
from stable_baselines3 import PPO
from stable_baselines3.common.callbacks import BaseCallback


class StepLogger(BaseCallback):
    def __init__(self, verbose=0):
        super().__init__(verbose)

    def _on_step(self) -> bool:
        print(f"Step: {self.num_timesteps}, Reward: {self.locals.get('rewards')}")
        return True  # True = Training fortsetzen
    
env = GodotEnv()
logger_callback = StepLogger()

"""
model = PPO( "MlpPolicy", env, verbose=2)
model.learn(total_timesteps=100, callback=logger_callback)
obs, info = env.reset()
print("Initial Obs:", obs) 
"""



for _ in range(10):
    action = env.action_space.sample()  # random
    obs, reward, terminated, truncated, info = env.step(action)
    print("Step:", obs, reward)

    if terminated or truncated:
        break

env.close()
