class_name AssetPaths
extends RefCounted
## Central asset path + atlas coord registry for Kenney sprite packs.
##
## Kenney roguelike sheets use 16x16 tiles with 1px margin — so a tile at
## (col, row) maps to Rect2(col * 17, row * 17, 16, 16).
##
## Paths point at the *_transparent.png variants (preferred over magenta).
## If the asset folder is missing/removed, SpriteUtil.try_sprite_or_colorrect
## falls back to ColorRects, so the game still runs.
##
## Coord picks below are initial guesses. Comments marked `# TUNE:` are where
## Eddie should eyeball the preview PNG and adjust (col, row) in-editor.


const CAVES_SHEET := "res://assets/sprites/kenney/kenney_roguelike-caves-dungeons/Spritesheet/roguelikeDungeon_transparent.png"
const OUTDOOR_SHEET := "res://assets/sprites/kenney/kenney_roguelike-caves-dungeons/Spritesheet/roguelikeSheet_transparent.png"
const CHARACTER_SHEET := "res://assets/sprites/kenney/kenney_roguelike-characters/Spritesheet/roguelikeChar_transparent.png"

const TILE_SIZE := 16
const TILE_MARGIN := 1


static func tile_rect(col: int, row: int) -> Rect2:
	## Rect2 for tile at (col, row) in a 16px + 1px margin grid.
	return Rect2(
		col * (TILE_SIZE + TILE_MARGIN),
		row * (TILE_SIZE + TILE_MARGIN),
		TILE_SIZE,
		TILE_SIZE
	)


# --- Entity coords ---------------------------------------------------------
# Dictionary shape: { "sheet": <path>, "col": int, "row": int }
# SpriteUtil.try_sprite_or_colorrect reads this shape directly.

# Player — leftmost column of the character sheet is full-body front-facing
# characters in various palettes. (0, 0) is a human-ish adventurer sprite
# (tan/flesh tones), a reasonable canary.
# TUNE: Eddie — scan col 0 for the character palette you like best and
# adjust `row`. Col 1 has robed/cloaked variants if you prefer a mage look.
const PLAYER_SPRITE := {"sheet": CHARACTER_SHEET, "col": 0, "row": 0}

# Walls — caves sheet has solid grey stone-wall blocks in the mid-upper region.
# Sprint 9 post-playtest: (6, 2) was hitting a decorative/transparent tile
# (Eddie: "wall is transparent dots"). Picking (8, 3) — deep inside the solid
# grey stone block, no edge caps, no decorations.
# TUNE: Eddie — (9, 3) and (10, 3) are equivalent; (7, 3) and (8, 2) also work.
const WALL_TILE := {"sheet": CAVES_SHEET, "col": 8, "row": 3}

# Floor — plain brown/tan dirt floor tile from the floor grid.
# Sprint 9 post-playtest: (6, 5) was in a transition area. Picking (12, 4),
# which sits in the solid brown dirt region (cols 11-14, rows 3-5 are all
# plain brown dirt, no edges or decoration).
# TUNE: (11, 4), (13, 4), (12, 3) are all similar solid brown tiles.
const FLOOR_TILE := {"sheet": CAVES_SHEET, "col": 12, "row": 4}

# Ores T1..T4 — keyed by OreData.id (matches _create_ore_types in
# floor_generator.gd). Sprint 9 post-playtest: re-picked from the actual gem
# cluster in the sheet. Gems sit in roughly cols 7-13, rows 8-9 — 8 distinct
# small colored gem sprites. Mineral tints are still applied via `modulate`
# on top of these sprites. Missing entries or load failures fall through to
# the ColorRect fallback in ore_node.gd.
#
# TUNE: Eddie — if a gem reads as the wrong colour on-screen, the tile coords
# here are easier to swap than the sheet. Adjacent cells in the gem cluster
# are all viable alternatives.
const ORE_SPRITES := {
	"iron":     {"sheet": CAVES_SHEET, "col": 8,  "row": 8},   # grey/silver gem
	"copper":   {"sheet": CAVES_SHEET, "col": 10, "row": 9},   # orange/brown gem
	"crystal":  {"sheet": CAVES_SHEET, "col": 9,  "row": 8},   # blue/cyan gem
	"silver":   {"sheet": CAVES_SHEET, "col": 11, "row": 8},   # pale/white gem
	"gold_ore": {"sheet": CAVES_SHEET, "col": 7,  "row": 9},   # yellow gem
	"obsidian": {"sheet": CAVES_SHEET, "col": 13, "row": 9},   # dark/black gem
	"diamond":  {"sheet": CAVES_SHEET, "col": 12, "row": 8},   # clear/white gem
	"mythril":  {"sheet": CAVES_SHEET, "col": 11, "row": 9},   # purple/magenta gem
}
