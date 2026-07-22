# assets/theme/colors.gd
# Kanonické farby Regnum Moravicum — zdroj: docs/ART_PROMPT_CANON.md
class_name RegnumColors
extends Object


const MORAVIA_CRIMSON := Color("8B1E2D")
const BYZANTINE_GOLD := Color("C9A227")
const PARCHMENT := Color("E8DCC4")
const OAK_DARK := Color("2A1F14")
const OAK_MID := Color("3D2E1F")
const FOREST_CANOPY := Color("2F4A28")
const MEADOW := Color("5A7A3A")
const DANUBE := Color("3A6B7A")
const STONE_WALL := Color("6B6560")
const MAGYAR_STEPPE := Color("A67C52")
const IRON_GREY := Color("4A4E52")
const SKY_DUSK_TOP := Color("4A3A4A")
const SKY_DUSK_BOT := Color("2A2030")
const ROYAL_BLUE := Color("2C3E6B")
const BYZANTINE_CRIMSON := Color("9B1B30")
const IVORY := Color("F2E8D5")
const BG_DARKER := Color("0A0806")
const TEXT_MUTED := Color("7A6B55")
const TEXT_SECONDARY := Color("B5A48A")
const BORDER_SOFT := Color(0.788, 0.635, 0.153, 0.22)  # byzantine-gold ~22% alpha
const SUCCESS := Color("5A9C5A")
const WARNING := Color("C9902F")
const RELIGION_ROME := Color("5A6B7A")
const RELIGION_BYZ := Color("C9A227")


static func gold_hairline() -> Color:
	return BORDER_SOFT
