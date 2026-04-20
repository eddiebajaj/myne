class_name CaveGen
extends RefCounted
## Cellular automata cave generator (Sprint 9 spec §A1).
##
## Deterministic per seed. Returns a 2D Array of bool (true = wall).
## Pure static helpers — no scene tree, no autoloads, no global RNG.
##
## Grid representation: Array of `height` rows, each row an Array[bool] of
## `width` columns, indexed as grid[y][x]. Array-of-Array was chosen over
## PackedByteArray for readability — cave grids top out ~3500 cells, so the
## per-cell Variant overhead is negligible versus the clarity win.
##
## Seeding contract: a local RandomNumberGenerator is seeded with the passed
## seed; the global RNG is never touched. Calling generate() twice with the
## same arguments always yields an identical grid.


## Generate a cave grid via cellular automata.
##
## width, height: grid dimensions (border cells are always walls).
## wall_chance: probability [0,1] that a non-border cell starts as wall.
## iterations: number of 4-5 rule smoothing passes (iterations<0 → 0 passes).
## seed: integer seed fed to a local RandomNumberGenerator.
##
## Returns a new Array[Array[bool]]. Inputs are not mutated. Degenerate sizes
## (width<3 or height<3) return a defensive all-walls grid of the clamped size.
static func generate(
	width: int,
	height: int,
	wall_chance: float,
	iterations: int,
	seed: int
) -> Array:
	# Defensive clamps: if the grid is too small to have any interior,
	# return a solid wall block of the requested size (or 1x1 if sub-1).
	if width < 3 or height < 3:
		var w: int = max(width, 1)
		var h: int = max(height, 1)
		return _make_filled_grid(w, h, true)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	# Initial population. Border cells forced to wall.
	var grid: Array = []
	grid.resize(height)
	for y in range(height):
		var row: Array = []
		row.resize(width)
		for x in range(width):
			if y == 0 or y == height - 1 or x == 0 or x == width - 1:
				row[x] = true
			else:
				row[x] = rng.randf() < wall_chance
		grid[y] = row

	# Smoothing passes: 4-5 rule with double-buffer to avoid in-place artifacts.
	var passes: int = max(iterations, 0)
	for _i in range(passes):
		grid = _smooth_pass(grid, width, height)

	return grid


## Return a new grid that keeps only the largest connected floor region.
## All other floor cells (smaller pockets) are converted to walls, so the
## returned grid has exactly one reachable floor region.
##
## Input grid is not mutated. Empty or degenerate grids return as-is (copied).
static func extract_largest_floor_region(grid: Array) -> Array:
	var height: int = grid.size()
	if height == 0:
		return []
	var width: int = (grid[0] as Array).size()
	if width == 0:
		return _copy_grid(grid)

	# visited[y][x] — tracks cells we've BFS'd from so we don't re-scan them.
	var visited: Array = _make_filled_grid(width, height, false)

	var best_region: Array = []  # Array[Vector2i]
	var best_size: int = 0

	for y in range(height):
		for x in range(width):
			if grid[y][x]:  # wall
				continue
			if visited[y][x]:
				continue
			var region: Array = _bfs_region(grid, visited, x, y, width, height)
			if region.size() > best_size:
				best_size = region.size()
				best_region = region

	# Build output grid: all walls, then open up the best region.
	var out: Array = _make_filled_grid(width, height, true)
	for cell in best_region:
		var v: Vector2i = cell
		out[v.y][v.x] = false
	return out


## BFS outward from (start_x, start_y) across floor cells only. Returns the
## floor cell Vector2i with the maximum BFS distance from start — i.e. the
## last cell dequeued before the queue empties. Useful for placing exits far
## from spawn.
##
## If the start cell is a wall or out of bounds, returns Vector2i(start_x, start_y)
## unchanged as a defensive signal.
static func bfs_farthest_floor_cell(grid: Array, start_x: int, start_y: int) -> Vector2i:
	var height: int = grid.size()
	if height == 0:
		return Vector2i(start_x, start_y)
	var width: int = (grid[0] as Array).size()
	if width == 0:
		return Vector2i(start_x, start_y)
	if start_x < 0 or start_x >= width or start_y < 0 or start_y >= height:
		return Vector2i(start_x, start_y)
	if grid[start_y][start_x]:
		return Vector2i(start_x, start_y)

	var visited: Array = _make_filled_grid(width, height, false)
	visited[start_y][start_x] = true

	var queue: Array = [Vector2i(start_x, start_y)]
	var last: Vector2i = Vector2i(start_x, start_y)
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		last = cur
		for d in _CARDINALS:
			var nx: int = cur.x + d.x
			var ny: int = cur.y + d.y
			if nx < 0 or nx >= width or ny < 0 or ny >= height:
				continue
			if visited[ny][nx]:
				continue
			if grid[ny][nx]:  # wall
				continue
			visited[ny][nx] = true
			queue.append(Vector2i(nx, ny))
	return last


## Return an Array[Vector2i] of every floor cell in the grid, scanning row-major.
## Useful as a spawn pool for entities so they never land on walls.
## Empty grids return an empty Array[Vector2i].
static func floor_cell_positions(grid: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var height: int = grid.size()
	if height == 0:
		return out
	var width: int = (grid[0] as Array).size()
	for y in range(height):
		for x in range(width):
			if not grid[y][x]:
				out.append(Vector2i(x, y))
	return out


# TODO: pick_spawn_and_exit(grid, seed) -> {spawn: Vector2i, exit: Vector2i} — convenience wrapper


# --- internal helpers ---------------------------------------------------------

const _CARDINALS: Array = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]


static func _make_filled_grid(width: int, height: int, value) -> Array:
	var g: Array = []
	g.resize(height)
	for y in range(height):
		var row: Array = []
		row.resize(width)
		for x in range(width):
			row[x] = value
		g[y] = row
	return g


static func _copy_grid(grid: Array) -> Array:
	var out: Array = []
	out.resize(grid.size())
	for y in range(grid.size()):
		var src: Array = grid[y]
		var dst: Array = []
		dst.resize(src.size())
		for x in range(src.size()):
			dst[x] = src[x]
		out[y] = dst
	return out


static func _smooth_pass(grid: Array, width: int, height: int) -> Array:
	# Produces a fresh grid. Border cells stay walls. Interior cells flip
	# based on the 3x3 neighborhood count (including self): wall if >=5.
	var out: Array = _make_filled_grid(width, height, true)
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var walls: int = 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if grid[y + dy][x + dx]:
						walls += 1
			out[y][x] = walls >= 5
	return out


static func _bfs_region(
	grid: Array,
	visited: Array,
	start_x: int,
	start_y: int,
	width: int,
	height: int
) -> Array:
	# BFS over 4-connected floor cells starting at (start_x, start_y).
	# Marks each discovered cell in `visited` (mutation is intentional — caller
	# owns the visited buffer and uses it to skip re-scanning across regions).
	var region: Array = []
	var queue: Array = [Vector2i(start_x, start_y)]
	visited[start_y][start_x] = true
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		region.append(cur)
		for d in _CARDINALS:
			var nx: int = cur.x + d.x
			var ny: int = cur.y + d.y
			if nx < 0 or nx >= width or ny < 0 or ny >= height:
				continue
			if visited[ny][nx]:
				continue
			if grid[ny][nx]:  # wall
				continue
			visited[ny][nx] = true
			queue.append(Vector2i(nx, ny))
	return region
