import websocket
import threading
import time
import queue

from myconverter.parser import Parser
from myconverter.function import FunctionHandler
from ki import init_model


class WebsocketClient:
    def __init__(self, server_url, log_queue):
        self.server_url = server_url
        self.log_queue = log_queue
        self.functionHandler = FunctionHandler()
        self.parser = Parser(self.functionHandler)
        self.ws = None
        self.receiver_thread = None
        self.reconnect_thread = None
        self.running = False
        self.should_reconnect = True

    def log(self, msg):
        self.log_queue.put(msg)

    def start(self):
        if self.running:
            self.log("Client is already running.")
            return

        try:
            self.ws = websocket.create_connection(self.server_url)
            self.log(f"✅ Connected to {self.server_url}")
            self.running = True
            self.receiver_thread = threading.Thread(target=self._receiver_loop, daemon=True)
            self.receiver_thread.start()
        except Exception as e:
            self.log(f"⚠️ Connection error: {e}")

    def stop(self):
        self.running = False
        try:
            if self.ws:
                self.ws.close()
                self.log("❌ Connection closed")
        except Exception:
            pass
        self.ws = None

    def start_reconnect_loop(self):
        self.should_reconnect = True
        self.reconnect_thread = threading.Thread(target=self._reconnect_loop, daemon=True)
        self.reconnect_thread.start()

    def stop_reconnect_loop(self):
        self.should_reconnect = False

    def _reconnect_loop(self):
        while self.should_reconnect:
            if not self.running:
                self.log("Attempting to reconnect...")
                self.start()
            time.sleep(3)

    def _receiver_loop(self):
        while self.running:
            try:
                message = self.ws.recv()
                if not message:
                    continue

                self.log(f"📩 Received: {message}")
                self._handle_message(message)

            except Exception as e:
                self.log(f"⚠️ Error in receiver loop: {e}")
                self.stop()
                break

    def _handle_message(self, message):
        converted_msg = self.parser.translate_to_actions(message)
        self.log(f"🔄 Converted message: {converted_msg}")

        if "create_function" in message:
            self.log("create function")
            self.functionHandler.load_functions()
            self.functionHandler.parse_func_definitions(message)
            self.functionHandler.save_functions()
            self.ws.send(self.functionHandler.functions)

        elif "load_fucinction" in message:
            self.log("load functions:")
            self.functionHandler.load_functions()
            self.log(str(self.functionHandler.functions))
            self.ws.send(self.functionHandler.functions)
            reply = self.ws.recv()
            if "OK" in reply:
                self.log(f"✅ Loading functions: {reply}")
            else:
                self.log(f"Couldnt load funcitons")

        elif "start ki" in message:
            print("Start Ki")
            init_model()

        elif "play_it_now" in message:
            for msg in converted_msg:
                payload = msg
                self.ws.send(payload)
                self.log(f"➡️ Sent action: {payload}")

                reply = self.ws.recv()
                self.log(f"✅ Received reply: {reply}")

                if "Stop Sequenz" in reply:
                    break

            self.ws.send("End Sequenz")
            reply = self.ws.recv()
            self.log(f"✅ Received End reply: {reply}")
