extends RefCounted

const BG_PANEL_DARK: String = "#0F1813"
const BG_CARD_DARK: String = "#111A15"
const BG_STATUS_DEFAULT: String = "#15251D"
const BORDER_GOLD: String = "#D4AF37"
const BORDER_GOLD_SOFT: String = "#C9A227"
const BORDER_SUBTLE: String = "#2B4034"
const ACCENT_POSITIVE: String = "#52B788"
const ACCENT_INFO: String = "#4EA8DE"
const ACCENT_WARNING: String = "#F3C969"
const ACCENT_DANGER: String = "#FF758F"
const TEXT_PRIMARY: String = "#FFFDF5"
const TEXT_MUTED: String = "#BDD3C6"

static func create_bold_font() -> SystemFont:
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Roboto", "Arial", "Liberation Sans", "sans-serif"])
	font.font_weight = 700
	return font

static func make_panel_style(
	bg_hex: String = BG_CARD_DARK,
	border_hex: String = BORDER_GOLD_SOFT,
	radius: int = 12,
	border_w: int = 2
) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(bg_hex)
	sb.border_color = Color(border_hex)
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	return sb

static func make_button_style(
	bg_hex: String,
	border_hex: String,
	border_w: int = 1,
	radius: int = 9,
	pressed_shift: bool = false,
	pad_h: float = 10.0
) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(bg_hex)
	sb.border_color = Color(border_hex)
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = 6.0 if pressed_shift else 5.0
	sb.content_margin_bottom = 4.0 if pressed_shift else 5.0
	return sb

static func format_brl(amount: int) -> String:
	var sign_str: String = "-" if amount < 0 else ""
	var digits: String = str(absi(amount))
	var out: String = ""
	var count: int = 0
	for idx: int in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "." + out
		out = digits.substr(idx, 1) + out
		count += 1
	return "%sR$ %s" % [sign_str, out]
