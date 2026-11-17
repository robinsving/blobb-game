extends RefCounted
## Chapter 2 mill rooms (format: scripts/flow_room.gd). Blobb's side is the left strip (controls 1-6),
## the fence (H) keeps him out of the duck's side. Found by a hill-climbing search for long shortest
## solutions, then checked by tools/solve_flow.py and tests/test_flow.gd:
##   room 1: 5 presses   room 2: 8 presses   room 3: 13 presses, and only with the "backwards" rule.
## After editing a room, run tools/solve_flow.py and update the lengths in tests/test_flow.gd.

const ROOMS := [
	{
		"rows": [
			"#############G#",
			"#.1.H.........#",
			"#.2.H....b....A",
			"#.3.B...D..#..#",
			"#.4.H.........#",
			"#P..H....a....#",
			"###############",
		],
		"spouts": {"A": {"dir": "<", "on": false}, "B": {"dir": ">", "on": true}},
		"boards": {"a": "/", "b": "\\"},
		"controls": {"1": "A", "2": "B", "3": "a", "4": "b"},
	},
	{
		"rows": [
			"#############G#",
			"#.1.Abc.......C",
			"#.2.HD........#",
			"#63.H.........#",
			"#.4.H.......###",
			"#P.5B.a.......#",
			"###############",
		],
		"spouts": {"A": {"dir": ">", "on": false}, "B": {"dir": ">", "on": false}, "C": {"dir": "<", "on": true}},
		"boards": {"a": "\\", "b": "/", "c": "\\"},
		"controls": {"1": "A", "2": "B", "3": "C", "4": "a", "5": "b", "6": "c"},
	},
	{
		"rows": [
			"#######A##B##G#",
			"#.1.H.....b.a.#",
			"#.2.C..#......#",
			"#63.H.........#",
			"#.4.H..#....c.#",
			"#P.5H.D.......#",
			"###############",
		],
		"spouts": {"A": {"dir": "v", "on": true}, "B": {"dir": "v", "on": false}, "C": {"dir": ">", "on": true}},
		"boards": {"a": "/", "b": "\\", "c": "/"},
		"controls": {"1": "A", "2": "B", "3": "C", "4": "a", "5": "b", "6": "c"},
		"needs_reverse": true,
	},
]
