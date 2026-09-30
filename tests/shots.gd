extends Node
## Скриншоты для проверки глазами. Нужен виртуальный экран (см. CLAUDE.md, раздел 14).
## Запуск: ... res://tests/shots.tscn -- battle, campaign (карта и вкладки), menu (круговое меню башен), gallery (все герои)
## Куда сохранять: переменная окружения SHOTS_DIR, по умолчанию папка user://shots.

var main: Node
var mode := "battle"
var t := 0.0
var step := 0
var dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		mode = args[0]
	Game.persist = false
	dir = OS.get_environment("SHOTS_DIR")
	if dir == "":
		dir = ProjectSettings.globalize_path("user://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var heroes := OS.get_environment("SHOTS_HEROES")   # например ashgar,morven
	if heroes != "":
		Game.loadout_heroes.assign(Array(heroes.split(",")))
	var scene := "res://scenes/campaign.tscn" if mode == "campaign" else "res://scenes/main.tscn"
	main = (load(scene) as PackedScene).instantiate()
	add_child(main)


func _shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir + "/" + shot_name + ".png")
	print("снимок ", shot_name)


func _process(delta: float) -> void:
	t += delta
	if mode == "gallery":
		if step == 0 and t > 0.3:
			for i in Defs.HERO_ORDER.size():
				var hero := Hero.new()
				hero.setup(Defs.HERO_ORDER[i], Vector2(90 + i * 100, 270))
				hero.face = 1.0 if i % 2 == 0 else -1.0
				hero.selected = i == 3
				main.units_root.add_child(hero)
				if i == 2:
					hero.rage = 5.0
				if i == 1:
					hero.hp = 100.0
			step = 1
			t = 0.0
		elif step == 1 and t > 0.5:
			_shot("gallery")
			get_tree().quit()
		return
	if mode == "campaign":
		if step == 0 and t > 0.4:
			_shot("campaign_heroes")
			main._panel.assign("hero", "kara")
			main._panel.select_slot("hero", 0)
			main._panel.show_tab("tower")
			step = 1
			t = 0.0
		elif step == 1 and t > 0.3:
			_shot("campaign_towers")
			main._panel.show_tab("spell")
			step = 2
			t = 0.0
		elif step == 2 and t > 0.3:
			_shot("campaign_spells")
			get_tree().quit()
		return
	if mode == "menu":
		if step == 0 and t > 0.3:
			main.build_tower(main.pads[1], "archer")
			main._select(main.pads[2])
			step = 1
			t = 0.0
		elif step == 1 and t > 0.4:
			_shot("menu_build")
			main._select(main.pads[1])
			step = 2
			t = 0.0
		elif step == 2 and t > 0.4:
			_shot("menu_upgrade")
			main._select(main.pads[6])
			step = 3
			t = 0.0
		elif step == 3 and t > 0.4:
			_shot("menu_top")
			get_tree().quit()
		return
	var g := get_node("/root/Game")
	if step == 0 and t > 0.3:
		g.gold = 3000
		main.build_tower(main.pads[2], "barracks")
		main.build_tower(main.pads[1], "archer")
		main.build_tower(main.pads[4], "mage")
		main.upgrade_tower(main.pads[2])
		main.start_wave()
		Engine.time_scale = 3.0
		step = 1
		t = 0.0
	elif step == 1 and t > 3.0:
		Engine.time_scale = 1.0
		main.select_hero(1)
		main.heroes[1].set_post(Vector2(380, 330))
		main.select_hero(0)
		main.spellbook.arm("frost")
		t = 0.0
		step = 2
	elif step == 2 and t > 1.5:
		# мышь виртуального экрана стоит в углу, поэтому круг-подсказку проверяем отдельно
		main.use_ability(0)
		main.spellbook.cast("meteors", Vector2(300, 400))
		_shot("h01_battle")
		t = 0.0
		step = 3
	elif step == 3 and t > 0.5:
		_shot("h02_effects")
		print("убито: ", g.kills, ", жизни: ", g.lives)
		get_tree().quit()
