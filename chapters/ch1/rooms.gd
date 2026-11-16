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
]
