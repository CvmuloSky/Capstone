extends Node3D

var peer = ENetMultiplayerPeer.new()
@export var player_scene : PackedScene
var hostnumpressed = 0

func _on_host_pressed() -> void:
	if hostnumpressed == 0:
		peer.create_server(1027)
		multiplayer.multiplayer_peer = peer
		multiplayer.peer_connected.connect(add_player)
		multiplayer.peer_disconnected.connect(del_player) 
		add_player()
		$CanvasLayer.hide()
		hostnumpressed = 1

func _on_join_pressed() -> void:
	peer.create_client("127.0.0.1", 1027)
	multiplayer.multiplayer_peer = peer
	$CanvasLayer.hide()

func exit_game(id):
	multiplayer.multiplayer_peer.close()
	hostnumpressed = 0

func add_player(id = 1):
	var player = player_scene.instantiate()
	player.name = str(id)
	call_deferred("add_child", player)

func del_player(id):
	rpc("_del_player", id)

@rpc("any_peer", "call_local")
func _del_player(id):
	if has_node(str(id)):
		get_node(str(id)).queue_free()
