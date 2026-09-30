class_name Combat
extends RefCounted
## Поиск врагов для способностей героев и заклинаний.


## Враги в круге. Летающих берём, только если air равен true.
static func area(center: Vector2, radius: float, air: bool) -> Array[Enemy]:
	var list: Array[Enemy] = []
	for e in Game.enemies():
		if e.flying and not air:
			continue
		if e.aim_point().distance_to(center) <= radius + e.radius:
			list.append(e)
	return list


## Враг, вокруг которого больше всего других врагов. Ищем только в круге reach от точки from.
static func best_cluster(from: Vector2, reach: float, radius: float, air: bool) -> Enemy:
	var best: Enemy = null
	var best_count := 0
	for e in Game.enemies():
		if (e.flying and not air) or e.aim_point().distance_to(from) > reach:
			continue
		var count := 0
		for o in Game.enemies():
			if (air or not o.flying) and o.aim_point().distance_to(e.aim_point()) <= radius:
				count += 1
		if count > best_count:
			best_count = count
			best = e
	return best
