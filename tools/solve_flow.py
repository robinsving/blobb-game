"""BFS solver for the ch2 mill puzzles. Mirrors scripts/flow_room.gd exactly; keep the two in sync.
Usage: python3 tools/solve_flow.py            (solves every room in chapters/ch2/flow_rooms.gd)
Prints each room's shortest solution (control presses), how many settled states exist, and, with
--reverse-off, whether the room can be solved without the "backwards" story rule.
"""
import re, sys
from collections import deque

DIR = {'>': (1, 0), '<': (-1, 0), '^': (0, -1), 'v': (0, 1)}
OFF, ON, BACK = 0, 1, 2


class Room:
    def __init__(self, spec, reverse_allowed):
        self.rows = spec['rows']
        self.h, self.w = len(self.rows), len(self.rows[0])
        self.reverse = reverse_allowed
        self.spouts, self.boards, self.controls = {}, {}, {}
        self.spout_at, self.board_at = {}, {}
        for y, row in enumerate(self.rows):
            assert len(row) == self.w, f'row {y} has width {len(row)}, expected {self.w}'
            for x, c in enumerate(row):
                p = (x, y)
                if c == 'D': self.duck0 = p
                elif c == 'G': self.goal = p
                elif c in spec.get('spouts', {}):
                    s = spec['spouts'][c]
                    self.spouts[c] = [p, DIR[s['dir']], ON if s.get('on') else OFF]
                    self.spout_at[p] = c
                elif c in spec.get('boards', {}):
                    self.boards[c] = [p, spec['boards'][c]]; self.board_at[p] = c
                elif c in '/\\':
                    k = f'fixed{x}_{y}'; self.boards[k] = [p, c]; self.board_at[p] = k
                elif c.isdigit():
                    self.controls[p] = spec['controls'][c]

    def solid(self, p):
        x, y = p
        return not (0 <= x < self.w and 0 <= y < self.h) or self.rows[y][x] == '#' or p in self.spout_at

    @staticmethod
    def bounce(d, shape):
        return (-d[1], -d[0]) if shape == '/' else (d[1], d[0])

    def trace(self, l, boards):
        p0, d, _ = self.spouts[l]
        p = (p0[0] + d[0], p0[1] + d[1]); out = []; seen = set()
        while not self.solid(p) and (p, d) not in seen:
            seen.add((p, d)); arrive = d
            b = self.board_at.get(p)
            if b: d = self.bounce(d, boards[b])
            out.append((p, arrive, d)); p = (p[0] + d[0], p[1] + d[1])
        return out

    def cut_traces(self, spouts, boards):
        # all streams grow together; one stops where it runs into another's water (A before B on a tie)
        traces = {l: self.trace(l, boards) for l in sorted(self.spouts) if spouts[l] != OFF}
        owner, cut, alive, k = {}, {}, list(traces), 0
        while alive:
            for l in list(alive):
                t = traces[l]
                if k >= len(t): alive.remove(l); continue
                cell = t[k][0]
                if cell in owner and owner[cell] != l: alive.remove(l); continue
                owner[cell] = l; cut[l] = k + 1
            k += 1
        return {l: traces[l][:cut.get(l, 0)] for l in traces}

    def streams(self, spouts, boards):
        flow = {}
        for l, cells in sorted(self.cut_traces(spouts, boards).items()):
            st = spouts[l]
            for p, arrive, dep in cells:
                if p in flow: continue
                flow[p] = dep if st == ON else (-arrive[0], -arrive[1])
        return flow

    def settle(self, duck, spouts, boards):
        flow = self.streams(spouts, boards); seen = set()
        for _ in range(400):
            if duck == self.goal: return 'goal', duck
            if duck in seen: return 'loop', duck
            seen.add(duck)
            d = flow.get(duck, (0, -1)); n = (duck[0] + d[0], duck[1] + d[1])
            if self.solid(n) or self.rows[n[1]][n[0]] == 'H': return ('goal' if duck == self.goal else 'rest'), duck  # the fence stops the duck
            if duck in flow and flow.get(n) == (-d[0], -d[1]): return 'rest', duck  # head-on: stays
            duck = n
        return 'loop', duck

    def press(self, c, spouts, boards):
        spouts, boards = dict(spouts), dict(boards); t = self.controls[c]
        if t in self.spouts:
            spouts[t] = (spouts[t] + 1) % 3 if self.reverse else (OFF if spouts[t] != OFF else ON)
        else:
            boards[t] = '\\' if boards[t] == '/' else '/'
        return spouts, boards

    def solve(self):
        sp0 = {l: s[2] for l, s in self.spouts.items()}; bo0 = {b: v[1] for b, v in self.boards.items()}
        res, duck = self.settle(self.duck0, sp0, bo0)
        if res == 'goal': return [], 1
        key = lambda d, s, b: (d, tuple(sorted(s.items())), tuple(sorted(b.items())))
        q = deque([(duck, sp0, bo0, [])]); seen = {key(duck, sp0, bo0)}
        while q:
            duck, sp, bo, path = q.popleft()
            for c in self.controls:
                s2, b2 = self.press(c, sp, bo)
                res, d2 = self.settle(duck, s2, b2)
                if res == 'loop': continue
                if res == 'goal': return path + [c], len(seen)
                k = key(d2, s2, b2)
                if k in seen: continue
                seen.add(k); q.append((d2, s2, b2, path + [c]))
        return None, len(seen)


def load_rooms(path='chapters/ch2/flow_rooms.gd'):
    """Reads the GDScript room table (a JSON-ish literal) into Python dicts."""
    src = open(path).read()
    body = src[src.index('const ROOMS := ') + len('const ROOMS := '):]
    body = re.sub(r'(?m)^\s*#.*$', '', body)  # whole-line comments only: rows contain '#'
    body = body.replace('true', 'True').replace('false', 'False')
    return eval(body)


if __name__ == '__main__':
    for i, spec in enumerate(load_rooms()):
        for rev in ([True, False] if '--reverse-off' in sys.argv or spec.get('needs_reverse') else [False]):
            r = Room(spec, rev)
            sol, n = r.solve()
            names = ' '.join(r.rows[c[1]][c[0]] for c in sol) if sol else sol
            print(f'room {i + 1} reverse={rev}: {len(sol) if sol is not None else "UNSOLVABLE"} presses, {n} states: {names}')
