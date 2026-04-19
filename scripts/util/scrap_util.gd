class_name ScrapUtil
extends RefCounted
## Pure refund math for the Lab Scrap tab (Sprint 8 §A7).
##
## `compute_refund` converts an owned bot entry + its build-recipe hard-material
## spec into an array of `{ore_id, mineral_id, count}` rows representing the ores
## returned to the player on scrap. The function is side-effect free — callers
## use it both to preview the return in the confirm dialog AND to actually apply
## the scrap so the two can't disagree.
##
## Algorithm (per spec):
##   1. invested_points = BOT_BUILD_THRESHOLD (=10) + sum(UPGRADE_THRESHOLDS[0..upgrade_level-1])
##   2. refund_points   = floor(invested_points * 0.5)
##   3. Allocate refund into the bot's hard-material types (via ORE_POINTS_BY_TIER):
##      - single hard material: pack as many whole pieces as possible
##      - multi hard material (Backpack Bot: Iron + Copper): alternate one piece
##        of each in spec order until no more full piece of the current type fits
##   4. Remaining points → plain Iron filler at 1 pt each.
##
## Note: the spec's Backpack Lv 0 table row ("1 Iron + 1 Copper (4 pts) + 1 Iron
## filler = 2 Iron + 1 Copper") disagrees with the alternate algorithm when Iron
## and Copper are both T1 (1 pt each). This util follows the algorithm text:
## alternating Iron/Copper at 1 pt each over a 5-pt budget produces 3 Iron + 2
## Copper (Iron, Copper, Iron, Copper, Iron). Flagged in the PR summary.


## Returns array of {ore_id: String, mineral_id: String, count: int} rows.
## `required_materials_spec` is the `BOT_REQUIRED_MATERIALS[bot_id]` array from
## npc_lab.gd, e.g. [{ore_id: "iron", mineral_id: "", count: 3}]. Only the ore_id
## and mineral_id fields are used — the recipe's "count" is ignored because we're
## converting a point budget back to pieces, not replaying the recipe.
static func compute_refund(bot: Dictionary, required_materials_spec: Array) -> Array:
	var upgrade_level: int = int(bot.get("upgrade_level", 0))
	var invested: int = Inventory.BOT_BUILD_THRESHOLD
	for i in range(upgrade_level):
		if i < Inventory.UPGRADE_THRESHOLDS.size():
			invested += int(Inventory.UPGRADE_THRESHOLDS[i])
	var refund_pts: int = int(floor(float(invested) * 0.5))

	# Aggregated result, keyed by "ore_id:mineral_id".
	var agg: Dictionary = {}

	# Filter the hard-material spec down to usable rows (non-empty ore_id) and
	# compute the per-piece point cost from the ore tier.  We don't have direct
	# access to a tier lookup in the util, so use an in-module table keyed by
	# known ore_id. Keep this in sync with floor_generator._create_ore_types —
	# it's only used for bot hard materials, so the set is small.
	var hard: Array = []
	for req in required_materials_spec:
		var ore_id: String = String(req.get("ore_id", ""))
		var mineral_id: String = String(req.get("mineral_id", ""))
		if ore_id == "":
			continue
		var tier: int = _tier_for_ore_id(ore_id)
		var pts_per_piece: int = int(Inventory.ORE_POINTS_BY_TIER.get(tier, 1))
		if pts_per_piece <= 0:
			continue
		hard.append({
			"ore_id": ore_id,
			"mineral_id": mineral_id,
			"pts_per_piece": pts_per_piece,
		})

	var remaining: int = refund_pts

	if hard.size() == 1:
		# Single hard material: pack as many whole pieces as possible.
		var h: Dictionary = hard[0]
		var pts: int = int(h.pts_per_piece)
		var n: int = remaining / pts
		if n > 0:
			_agg_add(agg, h.ore_id, h.mineral_id, n)
			remaining -= n * pts
	elif hard.size() > 1:
		# Multi hard material: alternate piece-by-piece in spec order, skipping
		# materials that don't fit until none does.
		var idx: int = 0
		var any_progress: bool = true
		while any_progress and remaining > 0:
			any_progress = false
			for step in range(hard.size()):
				var h2: Dictionary = hard[(idx + step) % hard.size()]
				var pts2: int = int(h2.pts_per_piece)
				if pts2 <= remaining:
					_agg_add(agg, h2.ore_id, h2.mineral_id, 1)
					remaining -= pts2
					any_progress = true
					idx = (idx + step + 1) % hard.size()
					break  # start the outer while over again from the new idx
	# hard.size() == 0: no recipe match (unknown bot id) — skip to iron filler.

	# Filler: remaining points → plain Iron at 1 pt each.
	if remaining > 0:
		_agg_add(agg, "iron", "", remaining)

	# Flatten aggregated dict to an ordered array. Preserve insertion order so
	# the preview line reads "5 Crystal, 2 Iron" (hard material first, filler
	# last) which matches the spec examples.
	var out: Array = []
	for k in agg.keys():
		out.append(agg[k])
	return out


static func _agg_add(agg: Dictionary, ore_id: String, mineral_id: String, count: int) -> void:
	if count <= 0:
		return
	var key: String = ore_id + ":" + mineral_id
	if agg.has(key):
		agg[key].count = int(agg[key].count) + count
	else:
		agg[key] = {"ore_id": ore_id, "mineral_id": mineral_id, "count": count}


## Tier lookup for refund math. Kept in sync with floor_generator._create_ore_types.
## Only the ore ids that can appear as bot hard-materials need to be listed; the
## fallback is tier 1 (1 pt/piece) which is the safe default for filler.
static func _tier_for_ore_id(ore_id: String) -> int:
	match ore_id:
		"iron", "copper": return 1
		"crystal", "silver": return 2
		"gold_ore", "obsidian": return 3
		"diamond", "mythril": return 4
		_: return 1


## Human-readable name for a refunded ore_id. Used by the confirm-view preview.
static func display_name_for_ore_id(ore_id: String) -> String:
	match ore_id:
		"iron": return "Iron"
		"copper": return "Copper"
		"crystal": return "Crystal"
		"silver": return "Silver"
		"gold_ore": return "Gold"
		"obsidian": return "Obsidian"
		"diamond": return "Diamond"
		"mythril": return "Mythril"
		_: return ore_id.capitalize()
