import tkinter as tk
import queue
from websocket_client import WebsocketClient
import config

class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Godot WebSocket Client")
        self.geometry("500x500")

        self.log_queue = queue.Queue()
        self.ws_client = WebsocketClient(config.WEBSOCKET_URL, self.log_queue)

        self._setup_ui()
        self._process_log_queue()

        self.ws_client.start_reconnect_loop()
        self.protocol("WM_DELETE_WINDOW", self._on_closing)

    def _setup_ui(self):
        self.log_box = tk.Text(self, state="disabled", wrap="word", height=20)
        self.log_box.pack(expand=True, fill="both", padx=5, pady=5)

        button_frame = tk.Frame(self)
        button_frame.pack(fill="x", pady=5)

        start_btn = tk.Button(button_frame, text="Start", command=self.ws_client.start, bg="lightgreen")
        start_btn.pack(side="left", padx=10)

        stop_btn = tk.Button(button_frame, text="Stop", command=self.ws_client.stop, bg="lightcoral")
        stop_btn.pack(side="left", padx=10)

        exit_btn = tk.Button(button_frame, text="Exit", command=self._on_closing)
        exit_btn.pack(side="right", padx=10)

    def _log(self, msg):
        self.log_box.config(state="normal")
        self.log_box.insert("end", msg + "\n")
        self.log_box.see("end")
        self.log_box.config(state="disabled")

    def _process_log_queue(self):
        try:
            while True:
                msg = self.log_queue.get_nowait()
                self._log(msg)
        except queue.Empty:
            pass
        self.after(100, self._process_log_queue)

    def _on_closing(self):
        self.ws_client.stop_reconnect_loop()
        self.ws_client.stop()
        self.destroy()

if __name__ == "__main__":
    app = App()
    app.mainloop()
