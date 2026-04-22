import stable_baselines3 as stb
from stable_baselines3.common.vec_env import DummyVecEnv

from ki import GodotEnv
from ki import StepLogger
import time
import numpy as np

class ModelTester:
    def __init__(self, model_path="trained_model_ppo"):
        self.model_path = model_path
        self.env = None
        self.model = None

    def load_model(self):
        """Lädt das trainierte Modell"""
        self.env = DummyVecEnv([lambda: GodotEnv()])

        try:
            self.model = stb.PPO.load(self.model_path, env=self.env)
            print(f"✅ Modell '{self.model_path}' erfolgreich geladen")
            return True
        except Exception as e:
            print(f"❌ Fehler beim Laden: {e}")
            # Versuche alternatives Modell
            try:
                self.model = stb.PPO.load(self.model_path + "2", env=self.env)
                print(f"✅ Alternativmodell geladen")
                return True
            except Exception as e2:
                print(f"❌ Auch Alternativmodell fehlgeschlagen: {e2}")
                return False

    def test_episodes(self, num_episodes=3, max_steps=1000, render_delay=0.02):
        """Testet das Modell über mehrere Episoden"""
        if not self.model:
            print("❌ Kein Modell geladen!")
            return

        print(f"\n🎯 Starte {num_episodes} Test-Episoden")

        episode_rewards = []
        episode_lengths = []

        for episode in range(num_episodes):
            print(f"\n📊 Episode {episode + 1}/{num_episodes}")

            obs = self.env.reset()
            total_reward = 0
            done = False
            steps = 0

            while not done and steps < max_steps:
                # Vorhersage mit dem trainierten Modell
                action, _ = self.model.predict(obs, deterministic=True)

                # Schritt im Environment
                obs, reward, done, info = self.env.step(action)

                total_reward += reward
                steps += 1

                # Fortschritt anzeigen
                if steps % 100 == 0:
                    print(f"   Schritt {steps}, Reward: {reward:.3f}, Total: {total_reward:.3f}")

                # Verzögerung für bessere Beobachtbarkeit
                time.sleep(render_delay)

            episode_rewards.append(total_reward)
            episode_lengths.append(steps)

            print(f"🏁 Episode {episode + 1} beendet")
            print(f"   Länge: {steps} Schritte")
            print(f"   Gesamtreward: {total_reward:.3f}")

            time.sleep(1)  # Pause zwischen Episoden

        # Statistik ausgeben
        self._print_statistics(episode_rewards, episode_lengths)

    def test_single_predictions(self, num_predictions=10):
        """Testet mehrere einzelne Vorhersagen"""
        if not self.model:
            print("❌ Kein Modell geladen!")
            return

        print(f"\n🔍 Teste {num_predictions} einzelne Vorhersagen")

        obs = self.env.reset()

        for i in range(num_predictions):
            action, states = self.model.predict(obs, deterministic=True)

            print(f"Vorhersage {i + 1}:")
            print(f"  Observation Shape: {obs.shape}")
            print(f"  Aktion: {action}")
            print(f"  States: {states}")

            # Führe die Aktion aus für nächste Observation
            obs, reward, done, info = self.env.step(action)
            print(f"  Reward: {reward:.3f}, Done: {done}")

            if done:
                obs = self.env.reset()
                print("  ⚠️ Environment reset")

            print("-" * 40)

    def _print_statistics(self, rewards, lengths):
        """Gibt Test-Statistiken aus"""
        print("\n📈 TEST STATISTIKEN:")
        print(f"Anzahl Episoden: {len(rewards)}")
        print(f"Durchschnittlicher Reward: {np.mean(rewards):.3f} ± {np.std(rewards):.3f}")
        print(f"Min/Max Reward: {np.min(rewards):.3f} / {np.max(rewards):.3f}")
        print(f"Durchschnittliche Länge: {np.mean(lengths):.1f} Schritte")
        print(f"Min/Max Länge: {np.min(lengths)} / {np.max(lengths)} Schritte")

    def close(self):
        """Ressourcen freigeben"""
        if self.env:
            self.env.close()
            print("✅ Environment geschlossen")

def main():
    tester = ModelTester()

    if tester.load_model():
        # Verschiedene Testmodi
        print("\n1. Teste einzelne Vorhersagen")
        tester.test_single_predictions(num_predictions=5)

        print("\n2. Teste vollständige Episoden")
        tester.test_episodes(num_episodes=3, max_steps=500, render_delay=0.01)

    tester.close()

if __name__ == "__main__":
    main()
