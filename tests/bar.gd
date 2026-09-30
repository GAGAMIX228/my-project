extends Node
## Проверка казармы отдельно: одна казарма против первой волны, считаем убитых бойцами.

var main: Node
var elapsed := 0.0
var started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	Engine.time_scale = 6.0


func _process(delta: float) -> void:
	elapsed += delta
	var g := get_node("/root/Game")
	if not started and elapsed > 0.2:
		started = true
		g.gold = 500
		main.build_tower(main.pads[2], "barracks")
		main.start_wave()
	var alive := get_tree().get_nodes_in_group("enemies").size()
	if started and (elapsed > 90.0 or (main.queue.is_empty() and alive == 0 and elapsed > 5.0)):
		var soldiers := get_tree().get_nodes_in_group("soldiers")
		var hp := []
		for s in soldiers:
			hp.append(snappedf(s.hp, 0.1))
		print("КАЗАРМА: убито %d из 6, жизни %d, бойцов %d, здоровье %s, время %d с" % [g.kills, g.lives, soldiers.size(), str(hp), int(elapsed)])
		get_tree().quit()
