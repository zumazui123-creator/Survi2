extends Node


# Server: TCP + WebSocket Upgrade
var _tcp_server := TCPServer.new()
var _ws_peers 	:= [] 
var ws_peer 	:= WebSocketPeer.new()

func _ready():
	_tcp_server.listen(8765)  # Port 8765
	print("Server gestartet auf ws://localhost:8765")
	
func send_text(text):
	ws_peer.send_text(text)
	

func net_commander() -> String:
	var action : String = ""

	if _tcp_server.is_connection_available():
		var tcp_peer = _tcp_server.take_connection()
		ws_peer = WebSocketPeer.new()
		ws_peer.accept_stream(tcp_peer)  # Upgrade zu WebSocket
		_ws_peers.append(ws_peer)
		print("Neuer Client verbunden!")

	for ws_peer in _ws_peers:
		ws_peer.poll()
		var state = ws_peer.get_ready_state()

		if state == WebSocketPeer.STATE_OPEN:
			# Nachrichten empfangen
			while ws_peer.get_available_packet_count() > 0:
				var packet = ws_peer.get_packet().get_string_from_utf8()

				var lines = packet.split(",", false)
				action = lines[0].strip_edges()
				
		elif state == WebSocketPeer.STATE_CLOSED:
			_ws_peers.erase(ws_peer)

	return action
