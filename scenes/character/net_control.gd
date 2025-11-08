extends Node

@onready var funcHandler = $"../FunctionHandler"

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

var _request_id_counter := 0

func send_rpc_request(method: String, params: Dictionary):
	var request = {
		"jsonrpc": "2.0",
		"method": method,
		"params": params,
		"id": _request_id_counter
	}
	_request_id_counter += 1
	var json_string = JSON.stringify(request)
	send_text(json_string)

func load_functions(parsed):
	print("load functions")
	if typeof(parsed) == TYPE_DICTIONARY:
		if parsed.has(Strings.RPC_METHOD_LOAD_FUNCTIONS):
			if parsed.has("result"):
				print("RPC Response (id: %s): %s" % [parsed.get("id", "N/A"), parsed["result"]])
				# Special handling for load_functions result
				if parsed["result"] is Dictionary:
					funcHandler.set_func(JSON.stringify(parsed["result"]))
			elif parsed.has("error"):
				printerr("RPC Error (id: %s): %s" % [parsed.get("id", "N/A"), parsed["error"]])

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
				var packet_string = current_peer.get_packet().get_string_from_utf8()

				var parsed = JSON.parse_string(packet_string)
				load_functions(parsed)

				# Fallback for original action processing
				var lines = packet_string.split(",", false)
				action = lines[0].strip_edges()

		elif state == WebSocketPeer.STATE_CLOSED:
			_ws_peers.erase(current_peer)
			print("Client disconnected.")

	return action
