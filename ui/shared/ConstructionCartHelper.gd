extends RefCounted

static func collect_player_monopolies(
	player_id: int,
	tiles: Array[Dictionary],
	owners_map: Dictionary[int, int],
	mortgaged_map: Dictionary[int, bool]
) -> Array[Dictionary]:
	var groups_order: Array[String] = []
	var groups_tiles: Dictionary[String, Array] = {}
	var groups_color: Dictionary[String, String] = {}

	for i: int in range(tiles.size()):
		var t: Dictionary = tiles[i]
		if str(t.get("type", "")) != "PROPERTY":
			continue
		var g: String = str(t.get("group", ""))
		if g == "":
			continue
		if not groups_tiles.has(g):
			groups_tiles[g] = []
			groups_order.append(g)
			groups_color[g] = str(t.get("color", "#2A9D8F"))
		(groups_tiles[g] as Array).append(i)

	var result: Array[Dictionary] = []
	for g: String in groups_order:
		var t_list: Array = groups_tiles[g]
		if t_list.is_empty():
			continue
		var owns_all: bool = true
		var any_mortgaged: bool = false
		for tid_var: Variant in t_list:
			var tid: int = int(tid_var)
			if owners_map.get(tid, -1) != player_id:
				owns_all = false
				break
			if mortgaged_map.get(tid, false):
				any_mortgaged = true
		if owns_all:
			var tile_indices: Array[int] = []
			for tid_var: Variant in t_list:
				tile_indices.append(int(tid_var))
			result.append({
				"group": g,
				"color_hex": groups_color.get(g, "#2A9D8F"),
				"tiles": tile_indices,
				"any_mortgaged": any_mortgaged
			})
	return result

static func evaluate_cart_state(
	monopolies: Array[Dictionary],
	tiles: Array[Dictionary],
	base_buildings: Dictionary[int, int],
	draft_buildings: Dictionary[int, int],
	bank_houses_left: int,
	bank_hotels_left: int,
	player_money: int
) -> Dictionary:
	var houses_delta: int = 0
	var hotels_delta: int = 0
	var net_cost: int = 0
	var changed_count: int = 0
	var balance_ok: bool = true
	var balance_msg: String = ""

	for m: Dictionary in monopolies:
		var g_tiles: Array = m.get("tiles", [])
		var any_mortgaged: bool = bool(m.get("any_mortgaged", false))
		var min_lvl: int = 99
		var max_lvl: int = -1
		for tid_var: Variant in g_tiles:
			var tid: int = int(tid_var)
			var base_l: int = clampi(int(base_buildings.get(tid, 0)), 0, 5)
			var draft_l: int = clampi(int(draft_buildings.get(tid, base_l)), 0, 5)
			min_lvl = mini(min_lvl, draft_l)
			max_lvl = maxi(max_lvl, draft_l)
			if any_mortgaged and draft_l > base_l:
				balance_ok = false
				balance_msg = "Desipoteque todos os lotes do grupo antes de construir."
			if draft_l != base_l:
				changed_count += 1
				var house_cost: int = int(tiles[tid].get("house_cost", 50)) if (tid >= 0 and tid < tiles.size()) else 50
				var sell_unit: int = floori(float(house_cost) * 0.5)
				if draft_l > base_l:
					net_cost += (draft_l - base_l) * house_cost
				else:
					net_cost -= (base_l - draft_l) * sell_unit

				var old_houses: int = base_l if base_l <= 4 else 0
				var old_hotels: int = 1 if base_l >= 5 else 0
				var new_houses: int = draft_l if draft_l <= 4 else 0
				var new_hotels: int = 1 if draft_l >= 5 else 0
				houses_delta += (new_houses - old_houses)
				hotels_delta += (new_hotels - old_hotels)

		if max_lvl - min_lvl > 1:
			balance_ok = false
			if balance_msg == "":
				balance_msg = "Construção equilibrada: diferença máxima entre lotes do mesmo grupo é 1 nível."

	var proj_houses_left: int = bank_houses_left - houses_delta
	var proj_hotels_left: int = bank_hotels_left - hotels_delta
	var proj_money: int = player_money - net_cost

	var valid: bool = (changed_count > 0) and balance_ok and (proj_houses_left >= 0) and (proj_hotels_left >= 0) and (proj_money >= 0)
	var reason: String = balance_msg
	if reason == "" and proj_houses_left < 0:
		reason = "Estoque insuficiente de casas no Banco (faltam %d)." % absi(proj_houses_left)
	elif reason == "" and proj_hotels_left < 0:
		reason = "Estoque insuficiente de hotéis no Banco (faltam %d)." % absi(proj_hotels_left)
	elif reason == "" and proj_money < 0:
		reason = "Saldo insuficiente para confirmar este carrinho."

	return {
		"valid": valid,
		"changed_count": changed_count,
		"net_cost": net_cost,
		"projected_money": proj_money,
		"projected_houses_left": proj_houses_left,
		"projected_hotels_left": proj_hotels_left,
		"reason": reason
	}
