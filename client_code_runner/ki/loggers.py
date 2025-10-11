
from stable_baselines3.common.callbacks import BaseCallback

class StepLogger(BaseCallback):
    def __init__(self, verbose=0):
        super().__init__(verbose)

    def _on_step(self) -> bool:
        print(f"Step: {self.num_timesteps}, Reward: {self.locals.get('rewards')}")

        return True  # True = Training fortsetzen
