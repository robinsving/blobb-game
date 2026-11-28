extends RefCounted
## Chapter 2 mill rooms (format: scripts/flow_room.gd). Blobb's side is the left strip: the wheels
## (spouts) in the left column, the levers (boards) in the right one; the fence (H) keeps him out of
## the duck's side. In the game the wheels are labelled by their spout (A, B, C) and the levers by
## their board (1, 2, 3); the digits here only place the controls. Found by a hill-climbing search for long shortest
## solutions, then checked by tools/solve_flow.py and tests/test_flow.gd:
##   room 1: 5 presses   room 2: 7 presses   room 3: 13 presses, and only with the "backwards" rule.
## After editing a room, run tools/solve_flow.py and update the lengths in tests/test_flow.gd.

const ROOMS := [
	{
		"rows": [
			"#############G#",
			"#1.3H.........#",
			"#2.4H....b....A",
			"#...B...D..#..#",
			"#...H.........#",
			"#.P.H....a....#",
			"###############",
		],
		"spouts": {"A": {"dir": "<", "on": false}, "B": {"dir": ">", "on": true}},
		"boards": {"a": "/", "b": "\\"},
		"controls": {"1": "A", "2": "B", "3": "a", "4": "b"},
	},
	{
		"rows": [
			"#############G#",
			"#1.4Abc.......C",
			"#2.5HD........#",
			"#3.6H.........#",
			"#...H.......###",
			"#.P.B.a.......#",
			"###############",
		],
		"spouts": {"A": {"dir": ">", "on": false}, "B": {"dir": ">", "on": false}, "C": {"dir": "<", "on": true}},
		"boards": {"a": "\\", "b": "/", "c": "\\"},
		"controls": {"1": "A", "2": "B", "3": "C", "4": "a", "5": "b", "6": "c"},
	},
	{
		"rows": [
			"#######A##B##G#",
			"#1.4H.....b.a.#",
			"#2.5C..#......#",
			"#3.6H.........#",
			"#...H..#....c.#",
			"#.P.H.D.......#",
			"###############",
		],
		"spouts": {"A": {"dir": "v", "on": true}, "B": {"dir": "v", "on": false}, "C": {"dir": ">", "on": true}},
		"boards": {"a": "/", "b": "\\", "c": "/"},
		"controls": {"1": "A", "2": "B", "3": "C", "4": "a", "5": "b", "6": "c"},
		"needs_reverse": true,
	},
]
