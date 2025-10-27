import stable_baselines3 as stb
from ki import GodotEnv
from ki import StepLogger
import numpy as np

def init_model():
  env = GodotEnv()
  n_states = 1000
  Q=np.zeros([n_states,4])
  logger_callback = StepLogger()
  episodes=10000
  alpha=0.5
  gamma=0.9
  G=0 #G is sum of rewards

  for episode in range(1,episodes+1):
    state=env.reset()
    done=False
    G=0
    while not done:
      # Select the action that has the highest value in the current state.
      if np.max(Q[state]) > 0:
          action = np.argmax(Q[state])

      # If there's no best action (only zeros), take a random one
      else:
          action = env.action_space.sample()

      new_state,reward,done,info,a=env.step(action)
      Q[state,action]+=alpha*(reward+gamma*np.max(Q[new_state])-Q[state,action])
      G+=reward
      state=new_state
    if episode%100==0:
        print(f"episode {episode} sum of  reward :{G}")
  env.close()
