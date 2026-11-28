extends RefCounted
## Ch1 clearing room layouts (legend in scripts/sokoban_grid.gd).
## Keep in sync with tools/solve_sokoban.py and the solutions in tests/test_sokoban.gd.

const ROOMS := [
	[
		"  #########  ",
		"  #...#...#  ",
		"  #.P.B..o#  ",
		"  #..#.B..## ",
		"  #.......GE ",
		"  #..o....## ",
		"  #########  ",
	],
	[
		"##############  ",
		"#....#~~.....#  ",
		"#.P.B.~~..o..#  ",
		"#..B..~~.....## ",
		"#...B.~~..B...GE",
		"#.....~~...o.## ",
		"##############  ",
	],
	[  # the tiny banana marches along the bottom row, one step for each step Blobb takes, and pushes
		# whatever is in its way. Blobb can't get behind a crate dropped into its row: the banana has to
		# push it along to the plates at the end, so the crate has to drop in while it's on the left.
		"##########     ",
		"#P..#..o.#     ",
		"#.B...B..GE    ",
		"#..#B..#.#     ",
		"#.....##.#     ",
		"#####.######   ",
		"#A.........oo# ",
		"###############",
	],
]
