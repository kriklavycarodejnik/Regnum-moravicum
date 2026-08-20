# scripts/ui/BattleViewTranslations.gd
# Translation maps shared between BattleView.gd and smoke test.
# No autoload or scene dependencies — safe to load from any context (headless, -s, scene).
extends RefCounted

const WINNER_MAP := {
	"attacker": "útočník",
	"defender": "obranca",
	"decisive_victory": "rozhodujúce víťazstvo",
	"major_victory": "veľké víťazstvo",
	"victory": "víťazstvo",
	"stalemate": "patová situácia",
	"narrow_victory": "tesné víťazstvo",
	"heroic_victory": "hrdinské víťazstvo",
}

const PHASE_MAP := {
	"attack": "útok",
	"counterattack": "protiútok",
	"decision": "rozhodnutie",
}

const FALLBACK_WINNER := "neznámy výsledok"
const FALLBACK_PHASE := "neznáma fáza"


static func translate_winner(w: String) -> String:
	return WINNER_MAP.get(w, FALLBACK_WINNER)


static func translate_phase(p: String) -> String:
	return PHASE_MAP.get(p, FALLBACK_PHASE)