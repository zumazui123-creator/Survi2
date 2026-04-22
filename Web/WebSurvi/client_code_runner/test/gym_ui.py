import tkinter as tk
from tkinter import ttk, messagebox, filedialog
from PIL import Image, ImageTk
import gymnasium as gym
import numpy as np
import threading
import time
from collections import deque
import random
import os
import json
from datetime import datetime
import warnings
import matplotlib
matplotlib.use('Agg')  # Nicht-interaktives Backend
import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg

# TensorFlow CUDA deaktivieren
os.environ['CUDA_VISIBLE_DEVICES'] = '-1'
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'  # Alle Warnings unterdrücken

import tensorflow as tf
from tensorflow.keras import Sequential
from tensorflow.keras.layers import Dense

# Warnings für visualkeras unterdrücken
warnings.filterwarnings('ignore', category=UserWarning, module='visualkeras')
import visualkeras

# Force CPU usage
tf.config.set_visible_devices([], 'GPU')


class ReplayBuffer:
    """Experience Replay Buffer für DQN Training"""
    def __init__(self, capacity=10000):
        self.buffer = deque(maxlen=capacity)
        self.capacity = capacity

    def add(self, state, action, reward, next_state, done):
        self.buffer.append((state, action, reward, next_state, done))

    def sample(self, batch_size):
        batch = random.sample(self.buffer, min(batch_size, len(self.buffer)))
        states, actions, rewards, next_states, dones = zip(*batch)
        return (np.array(states), np.array(actions), np.array(rewards),
                np.array(next_states), np.array(dones))

    def size(self):
        return len(self.buffer)


class DQNAgent:
    """Deep Q-Network Agent mit Target Network"""
    def __init__(self, state_size, action_size, neurons, learning_rate,
                 buffer_size=10000, epsilon_start=1.0, epsilon_min=0.01,
                 epsilon_decay=0.995, gamma=0.95):
        self.state_size = state_size
        self.action_size = action_size
        self.gamma = gamma
        self.epsilon = epsilon_start
        self.epsilon_min = epsilon_min
        self.epsilon_decay = epsilon_decay
        self.learning_rate = learning_rate
        self.neurons = neurons

        self.model = self._build_model(neurons)
        self.target_model = self._build_model(neurons)
        self.update_target_model()

        self.replay_buffer = ReplayBuffer(capacity=buffer_size)

    def _build_model(self, neurons):
        """Erstellt das neuronale Netz"""
        from tensorflow.keras.layers import Input

        model = Sequential()
        model.add(Input(shape=(self.state_size,)))
        model.add(Dense(neurons[0], activation='relu'))
        for n in neurons[1:]:
            model.add(Dense(n, activation='relu'))
        model.add(Dense(self.action_size, activation='linear'))
        model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=self.learning_rate),
                     loss='mse')
        return model

    def update_target_model(self):
        """Kopiert Gewichte vom Haupt- zum Target-Netzwerk"""
        self.target_model.set_weights(self.model.get_weights())

    def remember(self, state, action, reward, next_state, done):
        """Speichert Erfahrung im Replay Buffer"""
        self.replay_buffer.add(state, action, reward, next_state, done)

    def act(self, state):
        """Wählt Aktion mit Epsilon-Greedy Policy"""
        if np.random.rand() <= self.epsilon:
            return random.randrange(self.action_size)
        q_values = self.model.predict(state.reshape(1, -1), verbose=0)
        return np.argmax(q_values[0])

    def replay(self, batch_size=32):
        """Trainiert das Netzwerk mit Batch aus Replay Buffer"""
        if self.replay_buffer.size() < batch_size:
            return 0.0

        states, actions, rewards, next_states, dones = self.replay_buffer.sample(batch_size)

        # Berechne Target Q-Values
        target_q_values = self.model.predict(states, verbose=0)
        next_q_values = self.target_model.predict(next_states, verbose=0)

        for i in range(batch_size):
            if dones[i]:
                target_q_values[i][actions[i]] = rewards[i]
            else:
                target_q_values[i][actions[i]] = rewards[i] + self.gamma * np.max(next_q_values[i])

        # Training
        history = self.model.fit(states, target_q_values, epochs=1, verbose=0)

        # Epsilon decay
        if self.epsilon > self.epsilon_min:
            self.epsilon *= self.epsilon_decay

        return history.history['loss'][0]

    def save(self, filepath):
        """Speichert Model und Metadaten"""
        # Speichere Weights
        self.model.save_weights(filepath + '_weights.h5')

        # Speichere Metadaten
        metadata = {
            'state_size': self.state_size,
            'action_size': self.action_size,
            'neurons': self.neurons,
            'learning_rate': self.learning_rate,
            'gamma': self.gamma,
            'epsilon': self.epsilon,
            'epsilon_min': self.epsilon_min,
            'epsilon_decay': self.epsilon_decay,
            'buffer_size': self.replay_buffer.capacity
        }
        with open(filepath + '_metadata.json', 'w') as f:
            json.dump(metadata, f, indent=2)

    @classmethod
    def load(cls, filepath):
        """Lädt Model und Metadaten"""
        # Lade Metadaten
        with open(filepath + '_metadata.json', 'r') as f:
            metadata = json.load(f)

        # Erstelle Agent
        agent = cls(
            state_size=metadata['state_size'],
            action_size=metadata['action_size'],
            neurons=metadata['neurons'],
            learning_rate=metadata['learning_rate'],
            buffer_size=metadata['buffer_size'],
            epsilon_start=metadata['epsilon'],
            epsilon_min=metadata['epsilon_min'],
            epsilon_decay=metadata['epsilon_decay'],
            gamma=metadata['gamma']
        )

        # Lade Weights
        agent.model.load_weights(filepath + '_weights.h5')
        agent.update_target_model()

        return agent


class GymRLTrainer(tk.Tk):
    """Hauptanwendung für Gymnasium RL Training"""

    # Verfügbare Environments
    ENVIRONMENTS = {
        "CartPole-v1": {"max_steps": 500, "description": "Balanciere Stange auf Wagen", "type": "discrete"},
        "Acrobot-v1": {"max_steps": 500, "description": "Schwinge Akrobat nach oben", "type": "discrete"},
        "MountainCar-v0": {"max_steps": 200, "description": "Fahre Auto auf Berg", "type": "discrete"},
        "LunarLander-v3": {"max_steps": 1000, "description": "Lande Raumschiff sicher", "type": "discrete"},
        "MountainCarContinuous-v0": {"max_steps": 999, "description": "Fahre Auto auf Berg (kontinuierlich)", "type": "continuous"},
    }

    def __init__(self):
        super().__init__()
        self.title("Gymnasium RL Trainer (Enhanced)")
        self.geometry("1600x900")

        # State
        self.env = None
        self.agent = None
        self.env_id = None
        self.is_training = False
        self.training_thread = None

        # Training History für Plots
        self.rewards_history = []
        self.avg_rewards_history = []
        self.epsilon_history = []
        self.loss_history = []

        self._setup_ui()

    def _setup_ui(self):
        """Erstellt die UI mit horizontaler Teilung"""
        paned = ttk.PanedWindow(self, orient=tk.HORIZONTAL)
        paned.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)

        # Linke Seite: Environment & Training
        left_frame = ttk.Frame(paned, padding=10)
        paned.add(left_frame, weight=1)

        # Rechte Seite: Neuronales Netz & Visualisierung
        right_frame = ttk.Frame(paned, padding=10)
        paned.add(right_frame, weight=1)

        self._build_environment_panel(left_frame)
        self._build_neural_network_panel(right_frame)

    def _build_environment_panel(self, parent):
        """Erstellt Environment-Auswahl und Training-Kontrollen"""
        # Environment Auswahl
        env_frame = ttk.LabelFrame(parent, text="Environment Auswahl", padding=10)
        env_frame.pack(fill=tk.X, pady=(0, 10))

        ttk.Label(env_frame, text="Gymnasium Environment:").pack(anchor=tk.W, pady=(0, 5))
        self.env_var = tk.StringVar(value="CartPole-v1")
        env_combo = ttk.Combobox(env_frame, textvariable=self.env_var,
                                 values=list(self.ENVIRONMENTS.keys()),
                                 state="readonly", width=30)
        env_combo.pack(fill=tk.X, pady=(0, 5))

        self.env_desc_label = ttk.Label(env_frame, text="", foreground="gray")
        self.env_desc_label.pack(anchor=tk.W)

        # Training Parameter
        param_frame = ttk.LabelFrame(parent, text="Training Parameter", padding=10)
        param_frame.pack(fill=tk.X, pady=(0, 10))

        params = [
            ("Episoden:", "episodes_var", 100, 1, 10000),
            ("Max Steps/Episode:", "max_steps_var", 500, 10, 2000),
            ("Lernrate:", "learning_rate_var", 0.001, 0.0001, 0.1),
            ("Batch Size:", "batch_size_var", 32, 8, 128),
            ("Gamma (Discount):", "gamma_var", 0.95, 0.8, 0.99),
            ("Epsilon Start:", "epsilon_start_var", 1.0, 0.1, 1.0),
            ("Epsilon Min:", "epsilon_min_var", 0.01, 0.001, 0.5),
            ("Epsilon Decay:", "epsilon_decay_var", 0.995, 0.9, 0.9999),
            ("Replay Buffer Size:", "buffer_size_var", 10000, 1000, 100000),
            ("Target Update Freq:", "target_update_var", 10, 1, 100),
            ("Batches per Episode:", "batches_per_ep_var", 4, 1, 20),
        ]

        for i, (label, var_name, default, min_val, max_val) in enumerate(params):
            ttk.Label(param_frame, text=label).grid(row=i, column=0, sticky=tk.W, padx=5, pady=3)

            if "learning_rate" in var_name or "gamma" in var_name or "epsilon" in var_name:
                var = tk.DoubleVar(value=default)
            else:
                var = tk.IntVar(value=default)

            setattr(self, var_name, var)
            entry = ttk.Entry(param_frame, textvariable=var, width=15)
            entry.grid(row=i, column=1, padx=5, pady=3)

        # Jetzt Environment-Binding und Initialisierung
        env_combo.bind("<<ComboboxSelected>>", self._on_env_changed)
        self._on_env_changed()

        # Buttons
        btn_frame = ttk.Frame(parent)
        btn_frame.pack(pady=10)

        self.train_btn = ttk.Button(btn_frame, text="▶ Train", command=self.start_training, width=12)
        self.train_btn.grid(row=0, column=0, padx=3)

        self.stop_btn = ttk.Button(btn_frame, text="⏹ Stop", command=self.stop_training,
                                   width=12, state=tk.DISABLED)
        self.stop_btn.grid(row=0, column=1, padx=3)

        self.eval_btn = ttk.Button(btn_frame, text="📊 Evaluate", command=self.evaluate, width=12)
        self.eval_btn.grid(row=0, column=2, padx=3)

        self.play_btn = ttk.Button(btn_frame, text="🎮 Play", command=self.play, width=12)
        self.play_btn.grid(row=0, column=3, padx=3)

        # Model Management Buttons
        model_frame = ttk.Frame(parent)
        model_frame.pack(pady=5)

        ttk.Button(model_frame, text="💾 Save Model", command=self.save_model, width=15).grid(row=0, column=0, padx=3)
        ttk.Button(model_frame, text="📂 Load Model", command=self.load_model, width=15).grid(row=0, column=1, padx=3)

        # Fortschrittsbalken
        progress_frame = ttk.LabelFrame(parent, text="Training Progress", padding=10)
        progress_frame.pack(fill=tk.X, pady=(0, 10))

        self.progress_var = tk.DoubleVar(value=0)
        self.progress_bar = ttk.Progressbar(progress_frame, variable=self.progress_var,
                                           maximum=100, length=400, mode='determinate')
        self.progress_bar.pack(fill=tk.X, pady=(0, 5))

        self.progress_label = ttk.Label(progress_frame, text="Bereit", foreground="gray")
        self.progress_label.pack(anchor=tk.W)

        # Training Info
        info_frame = ttk.LabelFrame(parent, text="Training Log", padding=10)
        info_frame.pack(fill=tk.BOTH, expand=True)

        scroll = ttk.Scrollbar(info_frame)
        scroll.pack(side=tk.RIGHT, fill=tk.Y)

        self.info_text = tk.Text(info_frame, height=10, wrap=tk.WORD,
                                yscrollcommand=scroll.set, state=tk.DISABLED,
                                font=("Courier", 9))
        self.info_text.pack(fill=tk.BOTH, expand=True)
        scroll.config(command=self.info_text.yview)

        # Text Tags für Farben
        self.info_text.tag_config("success", foreground="green")
        self.info_text.tag_config("error", foreground="red")
        self.info_text.tag_config("warning", foreground="orange")
        self.info_text.tag_config("info", foreground="blue")

    def _build_neural_network_panel(self, parent):
        """Erstellt Neural Network Konfiguration und Visualisierung"""
        # Netzwerk Architektur
        arch_frame = ttk.LabelFrame(parent, text="Netzwerk Architektur", padding=10)
        arch_frame.pack(fill=tk.X, pady=(0, 10))

        ttk.Label(arch_frame, text="Hidden Layer Neuronen:").pack(anchor=tk.W, pady=(0, 5))
        ttk.Label(arch_frame, text="(kommasepariert, z.B. 128,64)",
                 foreground="gray", font=("TkDefaultFont", 8)).pack(anchor=tk.W, pady=(0, 5))

        self.neurons_var = tk.StringVar(value="128,64")
        ttk.Entry(arch_frame, textvariable=self.neurons_var, width=30).pack(fill=tk.X, pady=(0, 10))

        ttk.Button(arch_frame, text="🔍 Netzwerk Visualisieren",
                  command=self.visualize_network).pack(pady=5)

        # Notebook für verschiedene Visualisierungen
        notebook = ttk.Notebook(parent)
        notebook.pack(fill=tk.BOTH, expand=True)

        # Tab 1: Netzwerk Struktur
        struct_frame = ttk.Frame(notebook, padding=10)
        notebook.add(struct_frame, text="Netzwerk")

        canvas_frame = ttk.Frame(struct_frame)
        canvas_frame.pack(fill=tk.BOTH, expand=True)

        v_scroll = ttk.Scrollbar(canvas_frame, orient=tk.VERTICAL)
        v_scroll.pack(side=tk.RIGHT, fill=tk.Y)

        h_scroll = ttk.Scrollbar(canvas_frame, orient=tk.HORIZONTAL)
        h_scroll.pack(side=tk.BOTTOM, fill=tk.X)

        self.vis_canvas = tk.Canvas(canvas_frame, bg="white",
                                    yscrollcommand=v_scroll.set,
                                    xscrollcommand=h_scroll.set)
        self.vis_canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        v_scroll.config(command=self.vis_canvas.yview)
        h_scroll.config(command=self.vis_canvas.xview)

        self.vis_label = ttk.Label(self.vis_canvas,
                                   text="Visualisierung erscheint nach 'Netzwerk Visualisieren'",
                                   foreground="gray")
        self.vis_canvas.create_window(250, 150, window=self.vis_label)

        # Tab 2: Training Rewards
        reward_frame = ttk.Frame(notebook, padding=10)
        notebook.add(reward_frame, text="Rewards")

        self.reward_fig, self.reward_ax = plt.subplots(figsize=(6, 4))
        self.reward_canvas = FigureCanvasTkAgg(self.reward_fig, master=reward_frame)
        self.reward_canvas.get_tk_widget().pack(fill=tk.BOTH, expand=True)

        # Tab 3: Epsilon & Loss
        metrics_frame = ttk.Frame(notebook, padding=10)
        notebook.add(metrics_frame, text="Metrics")

        self.metrics_fig, (self.epsilon_ax, self.loss_ax) = plt.subplots(2, 1, figsize=(6, 4))
        self.metrics_canvas = FigureCanvasTkAgg(self.metrics_fig, master=metrics_frame)
        self.metrics_canvas.get_tk_widget().pack(fill=tk.BOTH, expand=True)

        self._init_plots()

    def _init_plots(self):
        """Initialisiert die Plot-Bereiche"""
        # Reward Plot
        self.reward_ax.set_xlabel('Episode')
        self.reward_ax.set_ylabel('Reward')
        self.reward_ax.set_title('Training Rewards')
        self.reward_ax.grid(True, alpha=0.3)

        # Epsilon Plot
        self.epsilon_ax.set_xlabel('Episode')
        self.epsilon_ax.set_ylabel('Epsilon')
        self.epsilon_ax.set_title('Exploration Rate')
        self.epsilon_ax.grid(True, alpha=0.3)

        # Loss Plot
        self.loss_ax.set_xlabel('Episode')
        self.loss_ax.set_ylabel('Loss')
        self.loss_ax.set_title('Training Loss')
        self.loss_ax.grid(True, alpha=0.3)

        plt.tight_layout()

    def _update_plots(self):
        """Aktualisiert alle Plots mit neuen Daten"""
        if len(self.rewards_history) == 0:
            return

        episodes = list(range(1, len(self.rewards_history) + 1))

        # Reward Plot
        self.reward_ax.clear()
        self.reward_ax.plot(episodes, self.rewards_history, 'b-', alpha=0.3, label='Episode Reward')
        if len(self.avg_rewards_history) > 0:
            self.reward_ax.plot(episodes, self.avg_rewards_history, 'r-', linewidth=2, label='Avg (100)')
        self.reward_ax.set_xlabel('Episode')
        self.reward_ax.set_ylabel('Reward')
        self.reward_ax.set_title('Training Rewards')
        self.reward_ax.legend()
        self.reward_ax.grid(True, alpha=0.3)

        # Epsilon Plot
        self.epsilon_ax.clear()
        if len(self.epsilon_history) > 0:
            self.epsilon_ax.plot(episodes, self.epsilon_history, 'g-', linewidth=2)
        self.epsilon_ax.set_xlabel('Episode')
        self.epsilon_ax.set_ylabel('Epsilon')
        self.epsilon_ax.set_title('Exploration Rate')
        self.epsilon_ax.grid(True, alpha=0.3)

        # Loss Plot
        self.loss_ax.clear()
        if len(self.loss_history) > 0:
            valid_losses = [(i+1, l) for i, l in enumerate(self.loss_history) if l > 0]
            if valid_losses:
                ep, losses = zip(*valid_losses)
                self.loss_ax.plot(ep, losses, 'm-', linewidth=2)
        self.loss_ax.set_xlabel('Episode')
        self.loss_ax.set_ylabel('Loss')
        self.loss_ax.set_title('Training Loss')
        self.loss_ax.grid(True, alpha=0.3)

        plt.tight_layout()
        self.reward_canvas.draw()
        self.metrics_canvas.draw()

    def _on_env_changed(self, event=None):
        """Aktualisiert Beschreibung bei Environment-Wechsel"""
        env_name = self.env_var.get()
        desc = self.ENVIRONMENTS.get(env_name, {}).get("description", "")
        self.env_desc_label.config(text=desc)

        max_steps = self.ENVIRONMENTS.get(env_name, {}).get("max_steps", 500)
        self.max_steps_var.set(max_steps)

    def _log(self, message, tag=""):
        """Fügt Nachricht zum Info-Text mit optionalem Tag hinzu"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        full_message = f"[{timestamp}] {message}\n"

        self.info_text.config(state=tk.NORMAL)
        if tag:
            self.info_text.insert(tk.END, full_message, tag)
        else:
            self.info_text.insert(tk.END, full_message)
        self.info_text.see(tk.END)
        self.info_text.config(state=tk.DISABLED)

    def _update_progress(self, current, total, message=""):
        """Aktualisiert Fortschrittsbalken"""
        progress = (current / total) * 100 if total > 0 else 0
        self.progress_var.set(progress)

        if message:
            self.progress_label.config(text=message)
        else:
            self.progress_label.config(text=f"Episode {current}/{total} ({progress:.1f}%)")

    def _parse_neurons(self):
        """Parst Neuronen-String zu Liste"""
        try:
            neurons = [int(n.strip()) for n in self.neurons_var.get().split(",")]
            if not neurons or any(n <= 0 for n in neurons):
                raise ValueError
            return neurons
        except ValueError:
            messagebox.showerror("Fehler", "Ungültige Neuronenliste!\nBeispiel: 128,64")
            return None

    def visualize_network(self):
        """Visualisiert die Netzwerk-Architektur"""
        neurons = self._parse_neurons()
        if neurons is None:
            return

        try:
            self.env_id = self.env_var.get()
            temp_env = gym.make(self.env_id)
            state_size = temp_env.observation_space.shape[0]
            action_size = temp_env.action_space.n
            temp_env.close()

            model = Sequential()
            model.add(Dense(neurons[0], activation='relu', input_shape=(state_size,)))
            for n in neurons[1:]:
                model.add(Dense(n, activation='relu'))
            model.add(Dense(action_size, activation='linear'))

            visualkeras.layered_view(model, to_file="nn_vis.png", legend=True, spacing=50)

            img = Image.open("nn_vis.png")
            photo = ImageTk.PhotoImage(img)

            self.vis_canvas.delete("all")
            self.vis_canvas.create_image(0, 0, anchor=tk.NW, image=photo)
            self.vis_canvas.image = photo
            self.vis_canvas.config(scrollregion=self.vis_canvas.bbox("all"))

            self._log(f"✓ Netzwerk visualisiert: {neurons} + Output({action_size})", "success")

        except Exception as e:
            self._log(f"Visualisierung fehlgeschlagen: {str(e)}", "error")
            messagebox.showerror("Fehler", f"Visualisierung fehlgeschlagen:\n{str(e)}")

    def save_model(self):
        """Speichert das trainierte Modell"""
        if self.agent is None:
            messagebox.showwarning("Warnung", "Kein trainiertes Modell vorhanden!")
            return

        filepath = filedialog.asksaveasfilename(
            defaultextension="",
            filetypes=[("Model Files", "*")],
            title="Model Speichern",
            initialfile=f"model_{self.env_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        )

        if filepath:
            try:
                self.agent.save(filepath)
                self._log(f"✓ Model gespeichert: {os.path.basename(filepath)}", "success")
                messagebox.showinfo("Erfolg", "Model erfolgreich gespeichert!")
            except Exception as e:
                self._log(f"Fehler beim Speichern: {str(e)}", "error")
                messagebox.showerror("Fehler", f"Speichern fehlgeschlagen:\n{str(e)}")

    def load_model(self):
        """Lädt ein gespeichertes Modell"""
        filepath = filedialog.askopenfilename(
            filetypes=[("Metadata Files", "*_metadata.json")],
            title="Model Laden"
        )

        if filepath:
            try:
                # Entferne '_metadata.json' Suffix
                base_path = filepath.replace('_metadata.json', '')

                self.agent = DQNAgent.load(base_path)
                self.env_id = self.env_var.get()

                self._log(f"✓ Model geladen: {os.path.basename(base_path)}", "success")
                self._log(f"  State: {self.agent.state_size}, Actions: {self.agent.action_size}", "info")
                self._log(f"  Neurons: {self.agent.neurons}, Epsilon: {self.agent.epsilon:.3f}", "info")

                messagebox.showinfo("Erfolg", "Model erfolgreich geladen!")
            except Exception as e:
                self._log(f"Fehler beim Laden: {str(e)}", "error")
                messagebox.showerror("Fehler", f"Laden fehlgeschlagen:\n{str(e)}")

    def start_training(self):
        """Startet das RL Training in separatem Thread"""
        if self.is_training:
            messagebox.showwarning("Warnung", "Training läuft bereits!")
            return

        neurons = self._parse_neurons()
        if neurons is None:
            return

        # Reset History
        self.rewards_history = []
        self.avg_rewards_history = []
        self.epsilon_history = []
        self.loss_history = []

        self.is_training = True
        self.train_btn.config(state=tk.DISABLED)
        self.stop_btn.config(state=tk.NORMAL)
        self._update_progress(0, 100, "Training startet...")

        self.training_thread = threading.Thread(target=self._training_loop,
                                               args=(neurons,), daemon=True)
        self.training_thread.start()

    def stop_training(self):
        """Stoppt das Training"""
        self.is_training = False
        self.stop_btn.config(state=tk.DISABLED)
        self._log("⚠ Training wird gestoppt...", "warning")

    def _training_loop(self, neurons):
        """Haupt-Training-Loop (läuft in separatem Thread)"""
        try:
            # Setup
            self.env_id = self.env_var.get()
            max_steps = self.max_steps_var.get()
            episodes = self.episodes_var.get()
            batch_size = self.batch_size_var.get()
            target_update_freq = self.target_update_var.get()
            batches_per_episode = self.batches_per_ep_var.get()

            self._log(f"=== Training gestartet: {self.env_id} ===", "info")
            self._log(f"Episoden: {episodes}, Max Steps: {max_steps}", "info")
            self._log(f"Batch Size: {batch_size}, Target Update: alle {target_update_freq} Episoden", "info")

            # Erstelle Environment
            self.env = gym.make(self.env_id, max_episode_steps=max_steps)
            state_size = self.env.observation_space.shape[0]

            # Prüfe Action Space Typ
            if hasattr(self.env.action_space, 'n'):
                action_size = self.env.action_space.n
                action_type = "discrete"
            else:
                self._log("❌ Nur diskrete Action Spaces werden unterstützt!", "error")
                messagebox.showerror("Fehler",
                    "Dieses Environment hat einen kontinuierlichen Action Space.\n"
                    "DQN funktioniert nur mit diskreten Actions (CartPole, Acrobot, etc.).\n\n"
                    "Bitte wähle ein anderes Environment!")
                return

            # Erstelle Agent mit allen Parametern
            self.agent = DQNAgent(
                state_size=state_size,
                action_size=action_size,
                neurons=neurons,
                learning_rate=self.learning_rate_var.get(),
                buffer_size=self.buffer_size_var.get(),
                epsilon_start=self.epsilon_start_var.get(),
                epsilon_min=self.epsilon_min_var.get(),
                epsilon_decay=self.epsilon_decay_var.get(),
                gamma=self.gamma_var.get()
            )

            self._log(f"Agent erstellt: State({state_size}) → {neurons} → Action({action_size})", "success")
            self._log(f"Epsilon: {self.agent.epsilon:.3f} → {self.agent.epsilon_min:.3f} (Decay: {self.agent.epsilon_decay})", "info")
            self._log(f"Replay Buffer: {self.agent.replay_buffer.capacity} Experiences", "info")

            # Training
            rewards_window = deque(maxlen=100)

            for episode in range(episodes):
                if not self.is_training:
                    break

                state, _ = self.env.reset()
                total_reward = 0
                steps = 0

                for step in range(max_steps):
                    action = self.agent.act(state)
                    next_state, reward, terminated, truncated, _ = self.env.step(action)
                    done = terminated or truncated

                    self.agent.remember(state, action, reward, next_state, done)
                    state = next_state
                    total_reward += reward
                    steps += 1

                    if done:
                        break

                # Training nach Episode mit konfigurierbarer Anzahl Batches
                loss = 0
                if self.agent.replay_buffer.size() >= batch_size:
                    for _ in range(batches_per_episode):
                        loss += self.agent.replay(batch_size)
                    loss /= batches_per_episode

                # Target Network Update mit konfigurierbarer Frequenz
                if episode % target_update_freq == 0:
                    self.agent.update_target_model()

                # History aktualisieren
                rewards_window.append(total_reward)
                avg_reward = np.mean(rewards_window)

                self.rewards_history.append(total_reward)
                self.avg_rewards_history.append(avg_reward)
                self.epsilon_history.append(self.agent.epsilon)
                self.loss_history.append(loss)

                # Progress Update
                self._update_progress(episode + 1, episodes,
                                    f"Episode {episode+1}/{episodes} | Reward: {total_reward:.1f} | Avg: {avg_reward:.1f}")

                # Logging alle 10 Episoden
                if episode % 10 == 0 or episode == episodes - 1:
                    self._log(f"Episode {episode+1}/{episodes} | "
                            f"Reward: {total_reward:.2f} | "
                            f"Avg(100): {avg_reward:.2f} | "
                            f"Epsilon: {self.agent.epsilon:.3f} | "
                            f"Steps: {steps} | "
                            f"Buffer: {self.agent.replay_buffer.size()}")

                # Plot Update alle 5 Episoden
                if episode % 5 == 0:
                    self._update_plots()

            # Final Plot Update
            self._update_plots()
            self.env.close()

            if self.is_training:
                self._log(f"=== Training abgeschlossen! ===", "success")
                self._log(f"Durchschnittlicher Reward (letzte 100): {avg_reward:.2f}", "success")
                self._update_progress(episodes, episodes, f"Training abgeschlossen! Avg Reward: {avg_reward:.2f}")
                messagebox.showinfo("Erfolg", f"Training abgeschlossen!\nAvg Reward: {avg_reward:.2f}")
            else:
                self._log("=== Training abgebrochen ===", "warning")
                self._update_progress(episode + 1, episodes, "Training abgebrochen")

        except Exception as e:
            self._log(f"❌ FEHLER: {str(e)}", "error")
            messagebox.showerror("Trainingsfehler", str(e))

        finally:
            self.is_training = False
            self.train_btn.config(state=tk.NORMAL)
            self.stop_btn.config(state=tk.DISABLED)

    def evaluate(self):
        """Evaluiert den trainierten Agenten"""
        if self.agent is None or self.env_id is None:
            messagebox.showwarning("Warnung", "Erst trainieren oder Model laden!")
            return

        try:
            self._log("\n--- Evaluation gestartet ---", "info")
            eval_env = gym.make(self.env_id, max_episode_steps=self.max_steps_var.get())

            num_episodes = 10
            rewards = []

            for ep in range(num_episodes):
                state, _ = eval_env.reset()
                total_reward = 0
                done = False

                while not done:
                    # Greedy Policy (kein Epsilon)
                    q_values = self.agent.model.predict(state.reshape(1, -1), verbose=0)
                    action = np.argmax(q_values[0])
                    state, reward, terminated, truncated, _ = eval_env.step(action)
                    done = terminated or truncated
                    total_reward += reward

                rewards.append(total_reward)
                self._log(f"Eval Episode {ep+1}: Reward = {total_reward:.2f}")

            eval_env.close()

            avg = np.mean(rewards)
            std = np.std(rewards)
            self._log(f"Evaluation Ergebnis: Avg = {avg:.2f} ± {std:.2f}", "success")
            messagebox.showinfo("Evaluation",
                              f"Durchschnitt: {avg:.2f}\nStd: {std:.2f}\n"
                              f"Min: {min(rewards):.2f}\nMax: {max(rewards):.2f}")

        except Exception as e:
            self._log(f"Evaluation Fehler: {str(e)}", "error")
            messagebox.showerror("Fehler", f"Evaluation fehlgeschlagen:\n{str(e)}")

    def play(self):
        """Spielt eine Episode mit Visualisierung"""
        if self.agent is None or self.env_id is None:
            messagebox.showwarning("Warnung", "Erst trainieren oder Model laden!")
            return

        def _play_thread():
            try:
                play_env = gym.make(self.env_id, render_mode="human",
                                   max_episode_steps=self.max_steps_var.get())

                state, _ = play_env.reset()
                total_reward = 0
                done = False
                steps = 0

                while not done:
                    # Greedy Action
                    q_values = self.agent.model.predict(state.reshape(1, -1), verbose=0)
                    action = np.argmax(q_values[0])

                    state, reward, terminated, truncated, _ = play_env.step(action)
                    done = terminated or truncated
                    total_reward += reward
                    steps += 1
                    time.sleep(0.02)

                play_env.close()

                self._log(f"▶ Play beendet: Reward = {total_reward:.2f}, Steps = {steps}", "success")
                messagebox.showinfo("Spiel beendet",
                                  f"Reward: {total_reward:.2f}\nSteps: {steps}")

            except Exception as e:
                self._log(f"Play Fehler: {str(e)}", "error")
                messagebox.showerror("Fehler", f"Play fehlgeschlagen:\n{str(e)}")

        threading.Thread(target=_play_thread, daemon=True).start()


if __name__ == "__main__":
    app = GymRLTrainer()
    app.mainloop()
