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
# Col 6, row 2 reads as a plain stone block (no top-edge cap) — works as a
# generic wall face tile when tiled in any direction.
# TUNE: Eddie — other clean options are (col 7, row 2) and (col 6, row 3).
# Col 6, row 0-1 have top-edge highlights if you want a ceiling-capped look.
const WALL_TILE := {"sheet": CAVES_SHEET, "col": 6, "row": 2}

# Floor — plain brown/tan dirt floor tile from the floor grid.
# Col 6, row 5 is a solid dirt tile that tiles cleanly.
# TUNE: (col 7, row 5) is similar; (col 4-5, row 8) is a cooler stone variant.
const FLOOR_TILE := {"sheet": CAVES_SHEET, "col": 6, "row": 5}

# Ores T1..T4 — keyed by OreData.id (matches _create_ore_types in
# floor_generator.gd). Caves sheet has small ore-pebble sprites in the
# top-left area (rows ~2-3) and colored gem sprites in the middle area
# (rows ~7-8). Mineral tints are still applied via `modulate` on top of
# these sprites. Missing entries or load failures fall through to the
# ColorRect fallback in ore_node.gd.
#
# TUNE: Eddie — these coords are first-pass picks from eyeballing the
# sheet preview. Rough regions:
#   - col 0-2, row 2: grey / brown / yellow pebble clumps (T1–T2 fits)
#   - col 5-8, row 7-8: colored gem sprites (T3–T4 flashier look)
# Adjust (col, row) per ore to taste.
const ORE_SPRITES := {
	"iron":     {"sheet": CAVES_SHEET, "col": 0, "row": 2},  # grey pebble cluster
	"copper":   {"sheet": CAVES_SHEET, "col": 1, "row": 2},  # brown/orange pebble
	"crystal":  {"sheet": CAVES_SHEET, "col": 5, "row": 7},  # blue gem
	"silver":   {"sheet": CAVES_SHEET, "col": 2, "row": 2},  # pale/yellow pebble
	"gold_ore": {"sheet": CAVES_SHEET, "col": 6, "row": 7},  # yellow gem
	"obsidian": {"sheet": CAVES_SHEET, "col": 7, "row": 8},  # dark/purple gem
	"diamond":  {"sheet": CAVES_SHEET, "col": 5, "row": 8},  # light cyan gem
	"mythril":  {"sheet": CAVES_SHEET, "col": 6, "row": 8},  # magenta/purple gem
}
