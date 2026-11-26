extends RefCounted

const UIStyleTokens = preload("res://ui/shared/UIStyleTokens.gd")

static func evaluate_trade_counterpart(offer_tile: int, request_tile: int, cash_delta: int) -> Dictionary:
	if offer_tile < 0 and request_tile < 0:
		return {
			"valid": false,
			"reason": "Selecione pelo menos uma escritura (troca unilateral só em dinheiro é bloqueada)."
		}
	if request_tile >= 0 and offer_tile < 0 and cash_delta <= 0:
		return {
			"valid": false,
			"reason": "Inclua uma escritura em troca ou ofereça dinheiro positivo pelo imóvel pedido."
		}
	if offer_tile >= 0 and request_tile < 0 and cash_delta >= 0:
		return {
			"valid": false,
			"reason": "Ao entregar um lote sem pedir outro, peça um valor em dinheiro (negativo) como pagamento."
		}
	return {
		"valid": true,
		"reason": ""
	}

static func format_trade_sides(
	offer_name: String,
	request_name: String,
	cash_delta: int
) -> Dictionary:
	var sender_items: Array[String] = []
	var target_items: Array[String] = []
	if offer_name != "":
		sender_items.append(offer_name)
	if cash_delta > 0:
		sender_items.append(UIStyleTokens.format_brl(cash_delta))
	if request_name != "":
		target_items.append(request_name)
	if cash_delta < 0:
		target_items.append(UIStyleTokens.format_brl(absi(cash_delta)))

	return {
		"sender_text": " + ".join(sender_items) if not sender_items.is_empty() else "Nada ofertado",
		"target_text": " + ".join(target_items) if not target_items.is_empty() else "Nada pedido"
	}

static func format_auction_status(
	current_bid: int,
	min_bid: int,
	highest_bidder_name: String
) -> String:
	if current_bid <= 0 or highest_bidder_name == "":
		return "Nenhum lance ainda • Lance inicial mínimo: %s" % UIStyleTokens.format_brl(min_bid)
	return "Maior lance: %s por %s" % [UIStyleTokens.format_brl(current_bid), highest_bidder_name]
