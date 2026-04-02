extends Node2D

func _ready():
	var game_state = get_node("/root/GameState")
	if game_state.has_method("register_shelter"):
		game_state.register_shelter()
		print("DeserterShelter registered.")

func _exit_tree():
	var game_state = get_node_or_null("/root/GameState")
	# 检查 GameState 是否还存在（避免游戏退出时报错）
	if game_state and game_state.has_method("unregister_shelter"):
		game_state.unregister_shelter()
		print("DeserterShelter unregistered.")
