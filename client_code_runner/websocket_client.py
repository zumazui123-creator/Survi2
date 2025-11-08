import websocket
import threading
import time
import queue
import json

from myconverter import constants
from myconverter.parser import Parser
from myconverter.function import FunctionHandler
from ki.model import init_model


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

    def _safe_send(self, data):
        """Safely send data to the websocket, handling potential connection errors."""
        if not self.ws or not self.running:
            self.log("⚠️ Cannot send: WebSocket is not connected.")
            return
        try:
            self.ws.send(data)
            return True
        except websocket.WebSocketConnectionClosedException:
            self.log("⚠️ Send failed: Connection is closed.")
            self.stop()
        except Exception as e:
            self.log(f"⚠️ An unexpected error occurred during send: {e}")
            self.stop()
        return False

    def start(self):
        if self.running:
            self.log("Client is already running.")
            return
        try:
            self.ws = websocket.create_connection(self.server_url, timeout=5)
            self.log(f"✅ Connected to {self.server_url}")
            self.running = True
            self.receiver_thread = threading.Thread(target=self._receiver_loop, daemon=True)
            self.receiver_thread.start()
        except websocket.WebSocketTimeoutException:
            self.log("⚠️ Connection timed out.")
        except ConnectionRefusedError:
            self.log("⚠️ Connection refused. Is the Godot server running?")
        except Exception as e:
            self.log(f"⚠️ An unexpected connection error occurred: {e}")

    def stop(self):
        if not self.running and self.ws is None:
            return # Already stopped
        self.running = False
        try:
            if self.ws:
                self.ws.close()
                self.log("❌ Connection closed")
        except websocket.WebSocketConnectionClosedException:
            self.log("ℹ️ Connection was already closed.")
        except Exception as e:
            self.log(f"⚠️ Error while closing connection: {e}")
        finally:
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
                # Handle each message in its own try-except block
                # to prevent one bad message from killing the client.
                try:
                    self._handle_message(message)
                except Exception as e:
                    self.log(f"CRITICAL: Unhandled error while processing message: {e}")
            except websocket.WebSocketTimeoutException:
                # This is not a critical error. It just means no message was received within the timeout.
                # We can just continue listening.
                self.log("Receiver loop timed out. Continuing to listen...")
                continue
            except websocket.WebSocketConnectionClosedException:
                self.log("ℹ️ Server closed the connection.")
                self.stop()
                break
            except Exception as e:
                self.log(f"⚠️ A critical error occurred in receiver loop: {e}")
                self.stop()
                break

    def _handle_message(self, message):
        try:
            if constants.CMD_CREATE_FUNCTION in message:
                try:
                    self.log("Executing 'create_function' block.")
                    self.functionHandler.load_functions()
                    self.functionHandler.parse_func_definitions(message)
                    self.functionHandler.save_functions()
                    self._safe_send(json.dumps(self.functionHandler.functions))
                except Exception as e:
                    self.log(f"⚠️ Error in 'create_function' block: {e}")

            elif constants.CMD_LOAD_FUNCTIONS in message:
                try:
                    self.log("Executing 'load_functions' block.")
                    functions = self.functionHandler.load_functions()
                    self.log(f"Loaded {len(functions)} functions.")
                    self._safe_send(json.dumps(functions))
                except Exception as e:
                    self.log(f"⚠️ Error in 'load_functions' block: {e}")

            elif constants.CMD_START_KI in message:
                try:
                    self.log("Executing 'start_ki' block.")
                    init_model()
                except Exception as e:
                    self.log(f"⚠️ Error in 'start_ki' block: {e}")

            elif constants.CMD_PLAY_SEQUENCE in message:
                try:
                    self.log("Executing 'play_it_now' block.")
                    converted_msg = self.parser.translate_to_actions(message)
                    self.log(f"🔄 Converted message: {converted_msg}")

                    for msg in converted_msg:
                        if not self._safe_send(msg):
                            self.log("Aborting sequence due to send failure.")
                            break
                        self.log(f"➡️ Sent action: {msg}")

                        try:
                            reply = self.ws.recv()
                            self.log(f"✅ Received reply: {reply}")
                            if constants.CMD_STOP_SEQUENCE in reply:
                                break
                        except websocket.WebSocketConnectionClosedException:
                            self.log("⚠️ Connection lost while waiting for action reply. Aborting sequence.")
                            return

                    if self._safe_send(constants.CMD_END_SEQUENCE):
                        try:
                            self.ws.recv()
                        except websocket.WebSocketConnectionClosedException:
                            self.log("⚠️ Connection lost while waiting for final reply.")
                            return
                except Exception as e:
                    self.log(f"⚠️ Error in 'play_it_now' block: {e}")

            else:
                self.log(f"⚠️ Received unknown message type: {message}")

        except Exception as e:
            # This outer block is a fallback for any truly unexpected errors.
            self.log(f"A critical, unexpected error occurred in _handle_message: {e}")