extends RefCounted

const PROFILE_AGRESSIVO: String = "AGRESSIVO"
const PROFILE_CONSERVADOR: String = "CONSERVADOR"
const PROFILE_MONOPOLISTA: String = "MONOPOLISTA"
const PROFILE_IMOBILIARIO: String = "IMOBILIARIO"
const PROFILE_ESPECULADOR: String = "ESPECULADOR"

const ALL_PROFILES: Array[String] = [
	PROFILE_AGRESSIVO,
	PROFILE_CONSERVADOR,
	PROFILE_MONOPOLISTA,
	PROFILE_IMOBILIARIO,
	PROFILE_ESPECULADOR
]

func assign_hidden_profiles(bot_count: int) -> Array[String]:
	var assigned: Array[String] = []
	var pool: Array[String] = []
	for i: int in range(bot_count):
		if pool.is_empty():
			pool = ALL_PROFILES.duplicate()
			pool.shuffle()
		var next_profile: String = str(pool.pop_back())
		assigned.append(next_profile)
	return assigned

func get_buy_reserve(profile: String) -> int:
	match profile:
		PROFILE_AGRESSIVO:
			return 140
		PROFILE_CONSERVADOR:
			return 520
		PROFILE_MONOPOLISTA:
			return 340
		PROFILE_IMOBILIARIO:
			return 260
		PROFILE_ESPECULADOR:
			return 210
		_:
			return 420

func get_build_reserve(profile: String) -> int:
	match profile:
		PROFILE_AGRESSIVO:
			return 180
		PROFILE_CONSERVADOR:
			return 600
		PROFILE_MONOPOLISTA:
			return 240
		PROFILE_IMOBILIARIO:
			return 150
		PROFILE_ESPECULADOR:
			return 300
		_:
			return 450

func get_unmortgage_reserve(profile: String) -> int:
	match profile:
		PROFILE_AGRESSIVO:
			return 220
		PROFILE_CONSERVADOR:
			return 640
		PROFILE_MONOPOLISTA:
			return 260
		PROFILE_IMOBILIARIO:
			return 190
		PROFILE_ESPECULADOR:
			return 320
		_:
			return 500

func should_use_jail_free_card(player: Dictionary, board_state: Dictionary) -> bool:
	if not bool(player.get("in_jail", false)):
		return false
	if int(player.get("jail_free_cards", 0)) <= 0:
		return false

	var profile: String = str(player.get("bot_profile", PROFILE_CONSERVADOR))
	var jail_turns: int = int(player.get("jail_turns", 0))
	var unowned_buyables: int = int(board_state.get("unowned_buyables", 0))

	match profile:
		PROFILE_AGRESSIVO:
			return unowned_buyables > 2 or jail_turns >= 1
		PROFILE_CONSERVADOR:
			return jail_turns >= 2 or unowned_buyables >= 12
		PROFILE_MONOPOLISTA:
			return unowned_buyables >= 6 or jail_turns >= 1
		PROFILE_IMOBILIARIO:
			return unowned_buyables >= 8 or jail_turns >= 2
		PROFILE_ESPECULADOR:
			return unowned_buyables >= 4 or int(player.get("money", 0)) >= 400
		_:
			return jail_turns >= 1

func should_pay_bail(player: Dictionary, bail_cost: int, board_state: Dictionary) -> bool:
	if not bool(player.get("in_jail", false)):
		return false
	var money: int = int(player.get("money", 0))
	if money < bail_cost:
		return false

	var profile: String = str(player.get("bot_profile", PROFILE_CONSERVADOR))
	var jail_turns: int = int(player.get("jail_turns", 0))
	var unowned_buyables: int = int(board_state.get("unowned_buyables", 0))
	var money_after: int = money - bail_cost

	match profile:
		PROFILE_AGRESSIVO:
			if unowned_buyables > 4 and money_after >= 140:
				return true
			return jail_turns >= 1 and money_after >= 220
		PROFILE_CONSERVADOR:
			if jail_turns >= 2 and money_after >= 320:
				return true
			return unowned_buyables >= 15 and money_after >= 750
		PROFILE_MONOPOLISTA:
			if unowned_buyables >= 6 and money_after >= 220:
				return true
			return jail_turns >= 2 and money_after >= 180
		PROFILE_IMOBILIARIO:
			if unowned_buyables >= 10 and money_after >= 260:
				return true
			return jail_turns >= 2 and money_after >= 240
		PROFILE_ESPECULADOR:
			if unowned_buyables >= 5 and money_after >= 180:
				return true
			return jail_turns >= 1 and money_after >= 300
		_:
			return jail_turns >= 2 and money_after >= 300

func should_buy_property(player: Dictionary, tile: Dictionary, tile_index: int, board_state: Dictionary) -> bool:
	var tile_type: String = str(tile.get("type", ""))
	if tile_type != "PROPERTY" and tile_type != "COMPANY":
		return false

	var price: int = int(tile.get("price", 0))
	var money: int = int(player.get("money", 0))
	if money < price:
		return false

	var profile: String = str(player.get("bot_profile", PROFILE_CONSERVADOR))
	var money_after: int = money - price
	var reserve: int = get_buy_reserve(profile)

	if tile_type == "COMPANY":
		match profile:
			PROFILE_ESPECULADOR:
				return money_after >= 100
			PROFILE_AGRESSIVO:
				return money_after >= reserve
			PROFILE_MONOPOLISTA:
				return money_after >= reserve + 260
			PROFILE_IMOBILIARIO:
				return money_after >= reserve + 200
			_:
				return money_after >= reserve + 140

	var player_id: int = int(player.get("id", -1))
	var group_name: String = str(tile.get("group", ""))
	var tiles_arr: Array[Dictionary] = _extract_tiles(board_state)
	var owners_map: Dictionary = board_state.get("property_owners", {})
	var teams_map: Dictionary = board_state.get("player_teams", {})

	var group_total: int = 0
	var owned_by_self: int = 0
	var owned_by_opponents: int = 0
	for i: int in range(tiles_arr.size()):
		var t: Dictionary = tiles_arr[i]
		if str(t.get("type", "")) == "PROPERTY" and str(t.get("group", "")) == group_name:
			group_total += 1
			if i == tile_index:
				continue
			if owners_map.has(i):
				var owner_id: int = int(owners_map[i])
				if _is_same_side(owner_id, player_id, teams_map):
					owned_by_self += 1
				else:
					owned_by_opponents += 1

	var completes_monopoly: bool = (group_total > 0 and owned_by_self == group_total - 1)
	var blocks_opponent: bool = (group_total > 0 and owned_by_opponents == group_total - 1)

	if completes_monopoly:
		var complete_floor: int = 120
		if profile == PROFILE_MONOPOLISTA or profile == PROFILE_AGRESSIVO:
			complete_floor = 30
		elif profile == PROFILE_IMOBILIARIO:
			complete_floor = 60
		elif profile == PROFILE_ESPECULADOR:
			complete_floor = 80
		return money_after >= complete_floor

	if blocks_opponent:
		var block_floor: int = 280
		if profile == PROFILE_MONOPOLISTA:
			block_floor = 60
		elif profile == PROFILE_AGRESSIVO:
			block_floor = 100
		elif profile == PROFILE_ESPECULADOR:
			block_floor = 140
		elif profile == PROFILE_IMOBILIARIO:
			block_floor = 200
		return money_after >= block_floor

	if owned_by_self > 0:
		var synergy_discount: int = 140 if profile == PROFILE_MONOPOLISTA else 80
		return money_after >= maxi(60, reserve - synergy_discount)

	match profile:
		PROFILE_IMOBILIARIO:
			# Prefere terrenos de custo de construção eficiente (até R$ 240)
			if price <= 240:
				return money_after >= maxi(140, reserve - 60)
			return money_after >= reserve + 120
		PROFILE_ESPECULADOR:
			# Foca terrenos mais valiosos de retorno alto
			if price >= 220:
				return money_after >= maxi(110, reserve - 80)
			return money_after >= reserve + 80
		PROFILE_MONOPOLISTA:
			# Se grupo já está dividido por adversário, evita imobilizar caixa sem bloquear
			if owned_by_opponents > 0:
				return money_after >= reserve + 180
			return money_after >= reserve
		_:
			return money_after >= reserve

func choose_building_to_buy(
	player: Dictionary,
	buildable_tiles: Array[int],
	tiles: Array[Dictionary],
	buildings: Dictionary[int, int],
	round_number: int = 1,
	market_push: bool = false
) -> int:
	if buildable_tiles.is_empty():
		return -1

	var profile: String = str(player.get("bot_profile", PROFILE_CONSERVADOR))
	var money: int = int(player.get("money", 0))
	var base_reserve: int = get_build_reserve(profile)
	var round_discount: int = mini(140, maxi(0, round_number - 3) * 20)
	if market_push:
		round_discount += 45
	var reserve: int = maxi(80, base_reserve - round_discount)

	var best_tile: int = -1
	var best_score: float = -999999.0

	for tile_idx: int in buildable_tiles:
		if tile_idx < 0 or tile_idx >= tiles.size():
			continue
		var tile: Dictionary = tiles[tile_idx]
		var house_cost: int = maxi(1, int(tile.get("house_cost", 50)))
		if money - house_cost < reserve:
			continue

		var current_lvl: int = buildings.get(tile_idx, 0)
		var rent_list: Array = tile.get("rent", [])
		var max_idx: int = maxi(0, rent_list.size() - 1)
		var cur_rent: int = int(rent_list[mini(current_lvl, max_idx)]) if rent_list.size() > 0 else 0
		var next_rent: int = int(rent_list[mini(current_lvl + 1, max_idx)]) if rent_list.size() > 0 else 0
		var rent_gain: float = float(next_rent - cur_rent)
		var roi: float = rent_gain / float(house_cost)

		var score: float = 0.0
		match profile:
			PROFILE_IMOBILIARIO:
				score = roi * 100.0 + rent_gain * 0.2
			PROFILE_AGRESSIVO:
				score = rent_gain * 2.0 + float(tile_idx)
			PROFILE_MONOPOLISTA:
				score = rent_gain * 1.5 - float(current_lvl) * 15.0
			PROFILE_ESPECULADOR:
				score = float(next_rent) + float(tile_idx) * 4.0
			_:
				score = roi * 60.0 - float(house_cost) * 0.5

		if best_tile == -1 or score > best_score:
			best_score = score
			best_tile = tile_idx

	return best_tile

func choose_tile_to_unmortgage(
	player: Dictionary,
	unmortgageable_tiles: Array[int],
	tiles: Array[Dictionary],
	interest_rate: float,
	property_owners: Dictionary[int, int]
) -> int:
	if unmortgageable_tiles.is_empty():
		return -1

	var profile: String = str(player.get("bot_profile", PROFILE_CONSERVADOR))
	var player_id: int = int(player.get("id", -1))
	var money: int = int(player.get("money", 0))
	var reserve: int = get_unmortgage_reserve(profile)

	var best_tile: int = -1
	var best_score: int = -1

	for tile_idx: int in unmortgageable_tiles:
		if tile_idx < 0 or tile_idx >= tiles.size():
			continue
		var tile: Dictionary = tiles[tile_idx]
		var mortgage_val: int = int(tile["mortgage"]) if tile.has("mortgage") else floori(float(tile.get("price", 0)) * 0.5)
		var redeem_cost: int = roundi(float(mortgage_val) * (1.0 + interest_rate))
		var in_monopoly: bool = _is_in_complete_monopoly(player_id, tile_idx, tiles, property_owners)

		var effective_reserve: int = reserve
		if in_monopoly and (profile == PROFILE_MONOPOLISTA or profile == PROFILE_IMOBILIARIO):
			effective_reserve = maxi(100, reserve - 100)

		if money - redeem_cost < effective_reserve:
			continue

		var price: int = int(tile.get("price", 0))
		var score: int = price + (500 if in_monopoly else 0)
		if profile == PROFILE_ESPECULADOR and str(tile.get("type", "")) == "COMPANY":
			score += 250

		if score > best_score:
			best_score = score
			best_tile = tile_idx

	return best_tile

func choose_liquidation_action(
	player: Dictionary,
	sellable_tiles: Array[int],
	mortgageable_tiles: Array[int],
	tiles: Array[Dictionary],
	buildings: Dictionary[int, int],
	property_owners: Dictionary[int, int]
) -> Dictionary:
	if int(player.get("money", 0)) >= 0:
		return { "action": "NONE", "tile_index": -1 }

	var profile: String = str(player.get("bot_profile", PROFILE_CONSERVADOR))
	var player_id: int = int(player.get("id", -1))

	# 1) Primeiro tenta hipotecar propriedades livres de construção (protegendo monopólios se possível)
	if not mortgageable_tiles.is_empty():
		var chosen_m: int = -1
		var lowest_priority: int = 999999
		for tile_idx: int in mortgageable_tiles:
			if tile_idx < 0 or tile_idx >= tiles.size():
				continue
			var tile: Dictionary = tiles[tile_idx]
			var price: int = int(tile.get("price", 0))
			var in_monopoly: bool = _is_in_complete_monopoly(player_id, tile_idx, tiles, property_owners)
			var priority: int = price + (1000 if in_monopoly else 0)
			if profile == PROFILE_ESPECULADOR and str(tile.get("type", "")) == "COMPANY":
				priority += 400
			if priority < lowest_priority:
				lowest_priority = priority
				chosen_m = tile_idx
		if chosen_m >= 0:
			return { "action": "MORTGAGE", "tile_index": chosen_m }

	# 2) Se não há o que hipotecar, vende construções equilibradamente
	if not sellable_tiles.is_empty():
		var chosen_s: int = -1
		var lowest_score: int = 999999
		for tile_idx: int in sellable_tiles:
			if tile_idx < 0 or tile_idx >= tiles.size():
				continue
			var house_cost: int = int(tiles[tile_idx].get("house_cost", 50))
			var lvl: int = buildings.get(tile_idx, 0)
			var score: int = house_cost * 10 - lvl
			if score < lowest_score:
				lowest_score = score
				chosen_s = tile_idx
		if chosen_s >= 0:
			return { "action": "SELL_BUILDING", "tile_index": chosen_s }

	return { "action": "NONE", "tile_index": -1 }

func should_end_turn(can_end: bool, has_pending_action: bool) -> bool:
	return can_end and not has_pending_action

func get_flavor_message(event_key: String, bot_name: String) -> String:
	# Frases neutras e variadas para jamais revelar o perfil interno do bot
	match event_key:
		"JAIL_CARD":
			return "%s apresentou o Salvo-Conduto e saiu livre do Xadrez." % bot_name
		"BAIL":
			return "%s pagou a fiança para voltar logo à estrada." % bot_name
		"BUY":
			return "%s decidiu investir e fechou negócio na escritura." % bot_name
		"DECLINE":
			return "%s avaliou a oferta e preferiu passar a compra." % bot_name
		"BUILD":
			return "%s aplicou recursos e ampliou suas construções." % bot_name
		"UNMORTGAGE":
			return "%s quitou a hipoteca para reativar a propriedade." % bot_name
		"LIQUIDATE":
			return "%s reorganizou o caixa para cobrir o saldo negativo." % bot_name
		"TRADE":
			return "%s conduziu uma negociação estratégica na mesa." % bot_name
		"END_TURN":
			return "%s finalizou as jogadas e passou a vez." % bot_name
		_:
			return "%s seguiu na rodada." % bot_name

func choose_bot_trade_proposal(
	proposer: Dictionary,
	all_players: Array[Dictionary],
	board_state: Dictionary,
	round_number: int,
	market_push: bool
) -> Dictionary:
	var empty_result: Dictionary = {}
	if bool(proposer.get("bankrupt", false)) or not bool(proposer.get("is_bot", false)):
		return empty_result
	var proposer_money: int = int(proposer.get("money", 0))
	if proposer_money < 120:
		return empty_result

	var tiles_arr: Array[Dictionary] = _extract_tiles(board_state)
	if tiles_arr.is_empty():
		return empty_result
	var owners_map: Dictionary = board_state.get("property_owners", {})
	var buildings_map: Dictionary = board_state.get("property_buildings", {})
	var mortgaged_map: Dictionary = board_state.get("mortgaged_tiles", {})
	var teams_map: Dictionary = board_state.get("player_teams", {})

	var proposer_id: int = int(proposer.get("id", -1))
	var profile: String = str(proposer.get("bot_profile", PROFILE_CONSERVADOR))
	var proposer_props: Array = proposer.get("properties", [])
	if proposer_props.is_empty():
		return empty_result

	# Lista de propriedades ofertáveis do proposer (sem construções no grupo e sem quebrar monopólio próprio)
	var offerable: Array[int] = []
	for p_var: Variant in proposer_props:
		var tid: int = int(p_var)
		if tid < 0 or tid >= tiles_arr.size():
			continue
		if _group_has_any_building(tid, tiles_arr, buildings_map):
			continue
		if _is_in_complete_monopoly_dict(proposer_id, tid, tiles_arr, owners_map, teams_map):
			continue
		offerable.append(tid)

	var best_proposal: Dictionary = {}
	var best_score: float = -1.0

	var proposer_reserve: int = maxi(100, get_buy_reserve(profile) - (80 if market_push else 30))
	if profile == PROFILE_MONOPOLISTA or profile == PROFILE_AGRESSIVO:
		proposer_reserve = maxi(80, proposer_reserve - 40)

	for target_var: Variant in all_players:
		if not (target_var is Dictionary):
			continue
		var target: Dictionary = target_var
		var target_id: int = int(target.get("id", -1))
		if target_id == proposer_id or bool(target.get("bankrupt", false)):
			continue
		if _is_same_side(proposer_id, target_id, teams_map):
			continue
		# Negociação automática ocorre apenas entre bots (nunca força troca em jogador humano)
		if not bool(target.get("is_bot", false)):
			continue

		var target_props: Array = target.get("properties", [])
		if target_props.is_empty():
			continue

		for req_var: Variant in target_props:
			var req_tile: int = int(req_var)
			if req_tile < 0 or req_tile >= tiles_arr.size():
				continue
			var req_data: Dictionary = tiles_arr[req_tile]
			if str(req_data.get("type", "")) != "PROPERTY":
				continue
			if _group_has_any_building(req_tile, tiles_arr, buildings_map):
				continue
			if _is_in_complete_monopoly_dict(target_id, req_tile, tiles_arr, owners_map, teams_map):
				continue

			var req_group: String = str(req_data.get("group", ""))
			var g_stats: Dictionary = _get_group_ownership_stats(proposer_id, req_group, tiles_arr, owners_map, teams_map)
			var g_total: int = int(g_stats["total"])
			var g_self: int = int(g_stats["self"])
			if g_total <= 0 or g_self <= 0:
				continue

			var completes_proposer: bool = (g_self == g_total - 1)
			# Só busca peça fora de monopólio iminente em rodadas mais avançadas ou Feira de Negócios
			if not completes_proposer and not (market_push or round_number >= 4):
				continue

			var req_val_for_proposer: float = _estimate_tile_strategic_value(
				req_tile, proposer_id, tiles_arr, owners_map, mortgaged_map, true, teams_map
			)

			# Candidato A: Troca cruzada (escritura + ajuste justo em dinheiro)
			for off_tile: int in offerable:
				if off_tile == req_tile:
					continue
				var off_data: Dictionary = tiles_arr[off_tile]
				var off_group: String = str(off_data.get("group", ""))
				if off_group != "" and off_group == req_group:
					continue

				var off_val_for_proposer: float = _estimate_tile_strategic_value(
					off_tile, proposer_id, tiles_arr, owners_map, mortgaged_map, false, teams_map
				)
				var off_val_for_target: float = _estimate_tile_strategic_value(
					off_tile, target_id, tiles_arr, owners_map, mortgaged_map, true, teams_map
				)
				var req_val_for_target: float = _estimate_tile_strategic_value(
					req_tile, target_id, tiles_arr, owners_map, mortgaged_map, false, teams_map
				)

				# Complemento justo em dinheiro (múltiplo de R$ 10, com margem amigável para aceitação mútua)
				var raw_diff: float = req_val_for_target - off_val_for_target
				var fair_cash_f: float = raw_diff * 1.08 if raw_diff >= 0.0 else raw_diff * 0.82
				var cash_delta: int = roundi(fair_cash_f / 10.0) * 10
				if completes_proposer and cash_delta < 0 and fair_cash_f > -40.0:
					cash_delta = 0

				var max_pay: int = proposer_money - proposer_reserve
				var target_money: int = int(target.get("money", 0))
				var max_ask: int = maxi(0, target_money - 160)
				cash_delta = clampi(cash_delta, -max_ask, maxi(0, max_pay))

				if cash_delta > 0 and proposer_money - cash_delta < proposer_reserve:
					continue
				if cash_delta < 0 and target_money - absi(cash_delta) < 120:
					continue

				# Checa se é vantajoso para o proposer
				var proposer_gain: float = req_val_for_proposer - off_val_for_proposer - float(cash_delta)
				if proposer_gain < 25.0:
					continue

				# Valida aceitação independente pelo bot alvo
				if evaluate_bot_trade_offer(target, proposer, off_tile, req_tile, cash_delta, board_state, round_number, market_push):
					var cash_efficiency_bonus: float = 95.0 if cash_delta <= 0 else 25.0
					var candidate_score: float = proposer_gain + cash_efficiency_bonus + (240.0 if completes_proposer else 40.0)
					if candidate_score > best_score:
						best_score = candidate_score
						best_proposal = {
							"target_id": target_id,
							"offer_tile": off_tile,
							"request_tile": req_tile,
							"cash_delta": cash_delta,
							"completes_monopoly": completes_proposer
						}

			# Candidato B: Compra direta em dinheiro com ágio justo (quando fecha monopólio e há folga de caixa)
			if completes_proposer and (market_push or round_number >= 2):
				var req_val_target: float = _estimate_tile_strategic_value(
					req_tile, target_id, tiles_arr, owners_map, mortgaged_map, false, teams_map
				)
				var premium_mult: float = 1.32 if market_push else 1.44
				var offer_cash: int = roundi((req_val_target * premium_mult) / 10.0) * 10
				offer_cash = maxi(60, offer_cash)
				if proposer_money - offer_cash >= proposer_reserve:
					var proposer_cash_gain: float = req_val_for_proposer - float(offer_cash)
					if proposer_cash_gain >= 20.0:
						if evaluate_bot_trade_offer(target, proposer, -1, req_tile, offer_cash, board_state, round_number, market_push):
							var cash_score: float = proposer_cash_gain + 180.0
							if cash_score > best_score:
								best_score = cash_score
								best_proposal = {
									"target_id": target_id,
									"offer_tile": -1,
									"request_tile": req_tile,
									"cash_delta": offer_cash,
									"completes_monopoly": true
								}

	return best_proposal

func evaluate_bot_trade_offer(
	receiver: Dictionary,
	proposer: Dictionary,
	offer_tile: int,
	request_tile: int,
	cash_delta: int,
	board_state: Dictionary,
	round_number: int,
	market_push: bool
) -> bool:
	if bool(receiver.get("bankrupt", false)) or bool(proposer.get("bankrupt", false)):
		return false
	var receiver_id: int = int(receiver.get("id", -1))
	var proposer_id: int = int(proposer.get("id", -1))
	if receiver_id < 0 or proposer_id < 0 or receiver_id == proposer_id:
		return false

	var tiles_arr: Array[Dictionary] = _extract_tiles(board_state)
	var owners_map: Dictionary = board_state.get("property_owners", {})
	var buildings_map: Dictionary = board_state.get("property_buildings", {})
	var mortgaged_map: Dictionary = board_state.get("mortgaged_tiles", {})
	var teams_map: Dictionary = board_state.get("player_teams", {})
	if _is_same_side(receiver_id, proposer_id, teams_map):
		return false

	# Exigir contrapartida mínima real e impedir venda/troca se algum grupo envolvido tiver construções
	if offer_tile < 0 and request_tile < 0:
		return false
	if request_tile >= 0 and offer_tile < 0 and cash_delta <= 0:
		return false
	if offer_tile >= 0 and request_tile < 0 and cash_delta >= 0:
		return false

	if request_tile >= 0:
		if request_tile >= tiles_arr.size() or not _is_same_side(int(owners_map.get(request_tile, -1)), receiver_id, teams_map):
			return false
		if _group_has_any_building(request_tile, tiles_arr, buildings_map):
			return false
		# Nunca entrega terreno de um monopólio que o destinatário já completou
		if _is_in_complete_monopoly_dict(receiver_id, request_tile, tiles_arr, owners_map, teams_map):
			return false

	if offer_tile >= 0:
		if offer_tile >= tiles_arr.size() or not _is_same_side(int(owners_map.get(offer_tile, -1)), proposer_id, teams_map):
			return false
		if _group_has_any_building(offer_tile, tiles_arr, buildings_map):
			return false

	var receiver_money: int = int(receiver.get("money", 0))
	var proposer_money: int = int(proposer.get("money", 0))
	if cash_delta > 0 and proposer_money < cash_delta:
		return false
	if cash_delta < 0 and receiver_money < absi(cash_delta):
		return false

	var receiver_money_after: int = receiver_money + cash_delta
	if receiver_money_after < 100:
		return false

	var profile: String = str(receiver.get("bot_profile", PROFILE_CONSERVADOR))
	var received_val: float = float(cash_delta)
	var receiver_completes_monopoly: bool = false
	if offer_tile >= 0:
		received_val += _estimate_tile_strategic_value(offer_tile, receiver_id, tiles_arr, owners_map, mortgaged_map, true, teams_map)
		var off_data: Dictionary = tiles_arr[offer_tile]
		if str(off_data.get("type", "")) == "PROPERTY":
			var off_stats: Dictionary = _get_group_ownership_stats(receiver_id, str(off_data.get("group", "")), tiles_arr, owners_map, teams_map)
			if int(off_stats["total"]) > 0 and int(off_stats["self"]) == int(off_stats["total"]) - 1:
				receiver_completes_monopoly = true

	var given_val: float = 0.0
	if request_tile >= 0:
		given_val = _estimate_tile_strategic_value(request_tile, receiver_id, tiles_arr, owners_map, mortgaged_map, false, teams_map)

	# Caso especial: humano está vendendo um lote para o Bot por dinheiro (request_tile == -1, cash_delta < 0)
	if request_tile < 0 and offer_tile >= 0 and cash_delta < 0:
		var buy_reserve: int = get_buy_reserve(profile)
		if receiver_money_after < buy_reserve and not receiver_completes_monopoly:
			return false
		var purchase_cost: float = float(absi(cash_delta))
		var offer_strategic: float = _estimate_tile_strategic_value(offer_tile, receiver_id, tiles_arr, owners_map, mortgaged_map, true, teams_map)
		var max_pay_ratio: float = 1.15 if receiver_completes_monopoly else 0.98
		return offer_strategic * max_pay_ratio >= purchase_cost

	# Penalidade se a entrega completa o monopólio do proposer (amenizada se receiver também completa monopólio ou precisa de caixa)
	var req_data: Dictionary = tiles_arr[request_tile]
	var gives_proposer_monopoly: bool = false
	if str(req_data.get("type", "")) == "PROPERTY":
		var p_stats: Dictionary = _get_group_ownership_stats(proposer_id, str(req_data.get("group", "")), tiles_arr, owners_map, teams_map)
		if int(p_stats["total"]) > 0 and int(p_stats["self"]) == int(p_stats["total"]) - 1:
			gives_proposer_monopoly = true

	if gives_proposer_monopoly and not receiver_completes_monopoly:
		var mono_tax: float = 0.24
		if profile == PROFILE_CONSERVADOR:
			mono_tax = 0.34
		elif profile == PROFILE_AGRESSIVO or profile == PROFILE_ESPECULADOR:
			mono_tax = 0.16
		elif profile == PROFILE_IMOBILIARIO:
			mono_tax = 0.20
		if market_push:
			mono_tax *= 0.65
		elif round_number >= 5:
			mono_tax *= 0.78
		given_val *= (1.0 + mono_tax)

	# Se o destinatário está com caixa apertado (< R$ 450), valoriza liquidez em dinheiro vivo
	if cash_delta > 0 and receiver_money < 450:
		received_val += float(cash_delta) * 0.22

	var required_margin: float = 1.05
	match profile:
		PROFILE_CONSERVADOR:
			required_margin = 1.14
		PROFILE_MONOPOLISTA:
			required_margin = 0.94 if receiver_completes_monopoly else 1.10
		PROFILE_AGRESSIVO:
			required_margin = 0.98
		PROFILE_IMOBILIARIO:
			required_margin = 0.96 if receiver_completes_monopoly else 1.06
		PROFILE_ESPECULADOR:
			required_margin = 1.02

	if market_push:
		required_margin = maxf(0.92, required_margin - 0.08)

	return received_val >= given_val * required_margin

func _is_same_side(pid_a: int, pid_b: int, teams_map: Dictionary) -> bool:
	if pid_a < 0 or pid_b < 0:
		return false
	if pid_a == pid_b:
		return true
	if teams_map.is_empty():
		return false
	var ta: int = int(teams_map.get(pid_a, -1))
	var tb: int = int(teams_map.get(pid_b, -1))
	return ta >= 0 and ta == tb

func _estimate_tile_strategic_value(
	tile_idx: int,
	viewer_id: int,
	tiles: Array[Dictionary],
	owners_map: Dictionary,
	mortgaged_map: Dictionary,
	is_acquiring: bool,
	teams_map: Dictionary = {}
) -> float:
	if tile_idx < 0 or tile_idx >= tiles.size():
		return 0.0
	var tile: Dictionary = tiles[tile_idx]
	var base_price: float = float(int(tile.get("price", 100)))
	var is_mort: bool = bool(mortgaged_map.get(tile_idx, false))
	var val: float = base_price * (0.62 if is_mort else 1.0)

	var t_type: String = str(tile.get("type", ""))
	if t_type != "PROPERTY":
		return val * 0.95

	var g_name: String = str(tile.get("group", ""))
	var stats: Dictionary = _get_group_ownership_stats(viewer_id, g_name, tiles, owners_map, teams_map)
	var total: int = int(stats["total"])
	var owned_self: int = int(stats["self"])
	if total <= 0:
		return val

	if is_acquiring:
		if owned_self == total - 1:
			# Fechar monopólio tem altíssimo valor estratégico
			val *= 1.85
		elif owned_self > 0:
			val *= 1.28
	else:
		if owned_self >= total:
			val *= 2.40
		elif owned_self >= 2:
			val *= 1.22
		else:
			# Peça solta em grupo fragmentado vale menos para manter parada
			val *= 0.94

	return val

func _get_group_ownership_stats(
	player_id: int,
	group_name: String,
	tiles: Array[Dictionary],
	owners_map: Dictionary,
	teams_map: Dictionary = {}
) -> Dictionary:
	var total: int = 0
	var self_count: int = 0
	if group_name == "":
		return { "total": 0, "self": 0 }
	for i: int in range(tiles.size()):
		var t: Dictionary = tiles[i]
		if str(t.get("type", "")) == "PROPERTY" and str(t.get("group", "")) == group_name:
			total += 1
			if owners_map.has(i) and _is_same_side(int(owners_map[i]), player_id, teams_map):
				self_count += 1
	return { "total": total, "self": self_count }

func _group_has_any_building(
	tile_idx: int,
	tiles: Array[Dictionary],
	buildings_map: Dictionary
) -> bool:
	if tile_idx < 0 or tile_idx >= tiles.size():
		return false
	if int(buildings_map.get(tile_idx, 0)) > 0:
		return true
	var g_name: String = str(tiles[tile_idx].get("group", ""))
	if g_name == "":
		return false
	for i: int in range(tiles.size()):
		var t: Dictionary = tiles[i]
		if str(t.get("type", "")) == "PROPERTY" and str(t.get("group", "")) == g_name:
			if int(buildings_map.get(i, 0)) > 0:
				return true
	return false

func _is_in_complete_monopoly_dict(
	player_id: int,
	tile_idx: int,
	tiles: Array[Dictionary],
	owners_map: Dictionary,
	teams_map: Dictionary = {}
) -> bool:
	if tile_idx < 0 or tile_idx >= tiles.size():
		return false
	var tile: Dictionary = tiles[tile_idx]
	if str(tile.get("type", "")) != "PROPERTY":
		return false
	var g_name: String = str(tile.get("group", ""))
	var stats: Dictionary = _get_group_ownership_stats(player_id, g_name, tiles, owners_map, teams_map)
	return int(stats["total"]) > 0 and int(stats["self"]) >= int(stats["total"])

func _is_in_complete_monopoly(
	player_id: int,
	tile_idx: int,
	tiles: Array[Dictionary],
	property_owners: Dictionary[int, int]
) -> bool:
	if tile_idx < 0 or tile_idx >= tiles.size():
		return false
	var tile: Dictionary = tiles[tile_idx]
	if str(tile.get("type", "")) != "PROPERTY":
		return false
	var group_name: String = str(tile.get("group", ""))
	if group_name == "":
		return false
	var count: int = 0
	for i: int in range(tiles.size()):
		var t: Dictionary = tiles[i]
		if str(t.get("type", "")) == "PROPERTY" and str(t.get("group", "")) == group_name:
			count += 1
			if property_owners.get(i, -1) != player_id:
				return false
	return count > 0

func choose_auction_bid(
	bot: Dictionary,
	tile: Dictionary,
	tile_index: int,
	current_bid: int,
	min_next_bid: int,
	board_state: Dictionary
) -> int:
	if bool(bot.get("bankrupt", false)):
		return 0
	var money: int = int(bot.get("money", 0))
	if money < min_next_bid:
		return 0

	var bot_id: int = int(bot.get("id", -1))
	var profile: String = str(bot.get("bot_profile", PROFILE_CONSERVADOR))
	var tiles_arr: Array[Dictionary] = _extract_tiles(board_state)
	var owners_map: Dictionary = board_state.get("property_owners", {})
	var mortgaged_map: Dictionary = board_state.get("mortgaged_tiles", {})
	var teams_map: Dictionary = board_state.get("player_teams", {})

	var base_price: int = int(tile.get("price", 100))
	var strategic_val: float = _estimate_tile_strategic_value(
		tile_index, bot_id, tiles_arr, owners_map, mortgaged_map, true, teams_map
	)
	if strategic_val <= 0.0:
		strategic_val = float(base_price)

	var mult: float = 1.05
	match profile:
		PROFILE_AGRESSIVO:
			mult = 1.24
		PROFILE_CONSERVADOR:
			mult = 0.88
		PROFILE_MONOPOLISTA:
			mult = 1.28
		PROFILE_IMOBILIARIO:
			mult = 1.12
		PROFILE_ESPECULADOR:
			mult = 1.15

	var reserve: int = maxi(80, floori(float(get_buy_reserve(profile)) * 0.7))
	var max_by_cash: int = maxi(0, money - reserve)
	var max_willing: int = mini(max_by_cash, roundi((strategic_val * mult) / 10.0) * 10)
	if min_next_bid > max_willing:
		return 0

	var jump: int = 0
	if current_bid > 0 and (profile == PROFILE_AGRESSIVO or profile == PROFILE_MONOPOLISTA) and (min_next_bid + 20) <= max_willing:
		jump = 20
	return mini(money, min_next_bid + jump)

func _extract_tiles(board_state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw: Variant = board_state.get("tiles", [])
	if raw is Array:
		for item: Variant in raw:
			if item is Dictionary:
				result.append(item)
	return result
