from godotEnv import GodotEnv
import gymnasium as gym

env = GodotEnv()

obs, info = env.reset()
print("Initial Obs:", obs)

for _ in range(10):
    action = env.action_space.sample()  # random
    obs, reward, terminated, truncated, info = env.step(action)
    print("Step:", obs, reward)

    if terminated or truncated:
        break

env.close()
