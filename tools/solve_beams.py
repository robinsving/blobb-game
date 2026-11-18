"""BFS solver for the ch3 rooftop rooms (light is solid). Mirrors scripts/beam_room.gd exactly; keep
the two in sync.
Usage: python3 tools/solve_beams.py    (solves every room in chapters/ch3/beam_rooms.gd)

Model (cell units, y grows downward, a room is W x H cells):
  '#' roof (solid)   'H' chimney (solid)   'A'..'F' lamps (solid)   '.' air
  'P' Blobb's start  'G' the goal (stand there)   '1'..'9' cranks (each turns one lamp)
Each lamp shines one way at a time; a crank steps it to the next direction in its list.
A beam runs from the lamp until it meets a solid cell or leaves the room. Light is solid:
every beam cell is something to stand on, at the middle of the cell (y = row + 0.5).
Roof tops are at y = row. Blobb can stand on a surface if the cell his body is in is open.
Moves: jump up at most 1.5 cells with at most 2 cells sideways, or move level/down with at
most 3 cells sideways, plus one more for every 2 cells of drop. Rooms keep every gap either
small (2 empty cells or fewer) or wide (5 or more), so the real jump agrees with this.
Light is one-way: Blobb can jump up through a beam but then lands on it, and never falls down
through one (or through what he stands on), so a jump is blocked by any surface in its arc
(see Room.crosses).
Turning a lamp under Blobb drops him to the next surface below, or off the room (a fail).

Two models. The STRICT one above is cautious, so a room it solves really can be solved. The
GENEROUS one (generous=True) gives Blobb more than his real jump (STRONG_JUMP rises 1.75 cells;
it ignores the arc and ceiling checks, and reaches 3 cells up a jump, 4 level or down, 5 after a
drop of 3.5 cells or more), so its shortest solution is a floor: no real shortcut beats it. A room
is honest when the strict model solves it and the generous shortest is the intended number of
turns (that's the one tests/test_beams.gd checks). Cranks are used standing in their own cell,
on the floor (chapters/ch3/roofs.gd), exactly as Room.at says.
"""
import re, sys
from collections import deque

DIRS = {'r': (1, 0), 'l': (-1, 0), 'u': (0, -1), 'ur': (1, -1), 'ul': (-1, -1), 'dr': (1, 1), 'dl': (-1, 1)}
LAMPS = 'ABCDEF'
UP_MAX, UP_DX, FLAT_DX = 3, 2, 3   # UP_MAX in half cells


class Room:
    def __init__(self, spec, generous=False):
        self.generous = generous
        self.rows = spec['rows']
        self.h, self.w = len(self.rows), len(self.rows[0])
        self.lamps, self.cranks = {}, {}
        for y, row in enumerate(self.rows):
            assert len(row) == self.w, f'row {y} has width {len(row)}, expected {self.w}'
            for x, c in enumerate(row):
                if c == 'P': self.start = (x, y)
                elif c == 'G': self.goal = (x, y)
                elif c in LAMPS: self.lamps[c] = {'pos': (x, y), 'dirs': spec['lamps'][c]['dirs'], 'start': spec['lamps'][c].get('start', 0)}
                elif c.isdigit(): self.cranks[(x, y)] = spec['controls'][c]
        self.order = sorted(self.lamps)

    def solid(self, x, y):
        if x < 0 or x >= self.w or y >= self.h: return True
        if y < 0: return False
        return self.rows[y][x] in '#H' + LAMPS

    def beam(self, l, state):
        x, y = self.lamps[l]['pos']; dx, dy = DIRS[self.lamps[l]['dirs'][state]]
        out = []
        x += dx; y += dy
        while 0 <= x < self.w and 0 <= y < self.h and not self.solid(x, y):
            out.append((x, y)); x += dx; y += dy
        return out

    def surfaces(self, states):
        """Every place Blobb can stand: (x, y2) with y2 = 2 * y (half cells)."""
        lit = set()
        for i, l in enumerate(self.order):
            lit.update(self.beam(l, states[i]))
        out = set()
        for x in range(self.w):
            for r in range(self.h):
                if self.solid(x, r) and not self.solid(x, r - 1) and r >= 1:
                    out.add((x, 2 * r))
                if (x, r) in lit and r >= 1 and not self.solid(x, r - 1):
                    out.add((x, 2 * r + 1))
        return out

    def clear_path(self, a, b):
        """The band at the higher end's body height is open in every column between a and b."""
        (x1, y1), (x2, y2) = a, b
        top = min(y1, y2)
        row = (top - 1) // 2 if top % 2 else top // 2 - 1
        lo, hi = sorted((x1, x2))
        for x in range(lo + 1, hi):
            if self.solid(x, row): return False
        return True

    def moves(self, p, surf):
        x1, y1 = p
        for q in surf:
            if q == p: continue
            x2, y2 = q; dx = abs(x2 - x1); up = y1 - y2
            if up > UP_MAX: continue
            if dx == 0 and up < 0: continue   # he can't fall through what he stands on
            if self.generous:
                if dx <= (3 if up > 0 else (5 if -up >= 7 else 4)): yield q
                continue
            # falling further gives more air time, so a long drop reaches a little further
            reach = UP_DX if up > 1 else FLAT_DX + max(0, -up) // 4
            if dx > reach: continue
            if dx > 0 and self.crosses(p, q, surf): continue
            if not self.clear_path(p, q): continue
            yield q

    def crosses(self, p, q, surf):
        """A jump from p to q would meet another surface on the way. Light is one-way, so Blobb can
        jump up through a beam but then lands on it, and he never falls down through one. Any
        surface in the columns he moves over (not his own) from one cell above the higher end down
        to just above the lower end blocks the move (surfaces at his own height there are just
        more floor, so walking covers those)."""
        lo, hi = sorted((p[0], q[0]))
        top, bottom = min(p[1], q[1]) - 2, max(p[1], q[1])
        return any(lo <= x <= hi and x != p[0] and (x, y) != q and top <= y < bottom
                   and not (y == p[1] and p[1] == q[1]) for (x, y) in surf)

    def region(self, p, surf):
        seen = {p}; q = deque([p])
        while q:
            a = q.popleft()
            for b in self.moves(a, surf):
                if b not in seen: seen.add(b); q.append(b)
        return seen

    def at(self, cell, p):
        """Blobb standing at p can use (or stands in) this cell: same column, body in that cell."""
        x, y2 = p
        return x == cell[0] and y2 in (2 * cell[1] + 1, 2 * cell[1] + 2)

    def fall(self, p, surf):
        x, y2 = p
        if p in surf: return p
        below = [y for (sx, y) in surf if sx == x and y > y2]
        return (x, min(below)) if below else None

    def start_state(self):
        st = tuple(self.lamps[l]['start'] for l in self.order)
        sx, sy = self.start
        return st, self.fall((sx, 2 * sy + 1), self.surfaces(st)) or (sx, 2 * sy + 2)

    def press(self, states, l):
        i = self.order.index(l); s = list(states)
        s[i] = (s[i] + 1) % len(self.lamps[l]['dirs'])
        return tuple(s)

    def solve(self, limit=200000):
        st, p = self.start_state()
        start = (st, p)
        q = deque([(st, p, [])]); seen = {start}
        while q:
            st, p, path = q.popleft()
            surf = self.surfaces(st)
            reg = self.region(p, surf)
            if any(self.at(self.goal, r) for r in reg): return path, len(seen)
            for c, l in self.cranks.items():
                for r in reg:
                    if not self.at(c, r): continue
                    st2 = self.press(st, l)
                    p2 = self.fall(r, self.surfaces(st2))
                    if p2 is None: continue
                    k = (st2, p2)
                    if k in seen: continue
                    seen.add(k); q.append((st2, p2, path + [c]))
                    if len(seen) > limit: return None, len(seen)
        return None, len(seen)


def load_rooms(path='chapters/ch3/beam_rooms.gd'):
    src = open(path).read()
    body = src[src.index('const ROOMS := ') + len('const ROOMS := '):]
    body = re.sub(r'(?m)^\s*#.*$', '', body)
    body = body.replace('true', 'True').replace('false', 'False')
    return eval(body)


if __name__ == '__main__':
    for i, spec in enumerate(load_rooms()):
        for label, g in (('strict', False), ('generous', True)):
            r = Room(spec, g)
            sol, n = r.solve()
            names = ' '.join(r.rows[c[1]][c[0]] for c in sol) if sol is not None else None
            print(f'room {i + 1} {label:8}: {len(sol) if sol is not None else "UNSOLVABLE"} presses, {n} states: {names}')
