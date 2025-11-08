extends Node

@onready var funcHandler = get_node("../FunctionHandler")

# Server: TCP + WebSocket Upgrade
var _tcp_server := TCPServer.new()
var _ws_peers 	:= []
var ws_peer 	:= WebSocketPeer.new()

func _ready():
	_tcp_server.listen(8765)  # Port 8765
	print("Server gestartet auf ws://localhost:8765")

func send_text(text: String):
	if ws_peer and ws_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws_peer.send_text(text)
	else:
		printerr("WebSocket not connected, cannot send text.")

func net_commander() -> String:
	var action : String = ""

	if _tcp_server.is_connection_available():
		var tcp_peer = _tcp_server.take_connection()
		ws_peer = WebSocketPeer.new()
		ws_peer.accept_stream(tcp_peer)  # Upgrade zu WebSocket
		_ws_peers.append(ws_peer)
		print("Neuer Client verbunden!")

	for current_peer in _ws_peers:
		current_peer.poll()
		var state = current_peer.get_ready_state()

		if state == WebSocketPeer.STATE_OPEN:
			while current_peer.get_available_packet_count() > 0:
				var packet = current_peer.get_packet().get_string_from_utf8()

				# Check if the packet is a JSON dictionary for functions
				if packet.begins_with("{") and packet.ends_with("}"):
					funcHandler.set_func(packet)
					# After handling, we can either continue or see if there's an action too.
					# For now, assume function packets are standalone.
					continue
				
				# Original action processing
				var lines = packet.split(",", false)
				action = lines[0].strip_edges()

		elif state == WebSocketPeer.STATE_CLOSED:
			_ws_peers.erase(current_peer)
			print("Client disconnected.")

	return action
