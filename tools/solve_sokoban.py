"""BFS solver for Blobb top-down rooms (same rules as scripts/sokoban_grid.gd).
Usage: python3 tools/solve_sokoban.py   (checks the rooms defined in ROOMS below / pass a file of rooms)
Legend: # wall, . floor, P player, B crate, o plate, * crate on plate, ~ water, G gate, E exit, ' ' void,
        A the banana: after each move Blobb makes, it takes one step along its row, pushing a crate ahead
        of it or shoving Blobb one cell (if there's room beyond), else it turns round
Crates pushed into water become walkable bridges. Gate opens when all plates hold crates.
"""
import sys
from collections import deque

def parse(rows):
    walls=set(); water=set(); crates=set(); plates=set(); gate=None; exit_=None; player=None; banana=None
    for y,row in enumerate(rows):
        for x,c in enumerate(row):
            p=(x,y)
            if c in '# ': walls.add(p)
            elif c=='~': water.add(p)
            elif c=='B': crates.add(p)
            elif c=='o': plates.add(p)
            elif c=='*': crates.add(p); plates.add(p)
            elif c=='P': player=p
            elif c=='G': gate=p
            elif c=='E': exit_=p
            elif c=='A': banana=p
    return walls,water,crates,plates,gate,exit_,player,banana

def solve(rows, floating=True, banana=True):
    walls,water,crates,plates,gate,exit_,player,ban=parse(rows)
    if not banana: ban=None
    def blocked(p,cr,br):  # for the banana and what it pushes
        return p in walls or p in cr or (p in water and p not in br) or p==gate or p==exit_
    def bstep(pl,cr,br,b,d):  # mirrors SokobanGrid.banana_step()
        if b is None: return pl,cr,b,d
        n=(b[0]+d,b[1])
        if n in walls or (n in water and n not in br) or n==gate or n==exit_: return pl,cr,b,-d
        if n==pl:
            t=(pl[0]+d,pl[1])
            if not blocked(t,cr,br): return t,cr,n,d
            return pl,cr,b,-d
        if n in cr:
            t=(n[0]+d,n[1])
            if not blocked(t,cr,br) and t!=pl: return pl,(cr-{n})|{t},n,d
            return pl,cr,b,-d
        return pl,cr,n,d
    start=(player,frozenset(crates),frozenset(),ban,1)
    seen={start:None}; q=deque([start])
    D={'R':(1,0),'L':(-1,0),'D':(0,1),'U':(0,-1)}
    while q:
        st=q.popleft(); pl,cr,br,b,d=st
        open_=plates<=cr
        if pl==exit_:
            path=[]; s=st
            while seen[s]: s,m=seen[s]; path.append(m)
            return ''.join(reversed(path))
        for m,(dx,dy) in D.items():
            n=(pl[0]+dx,pl[1]+dy)
            if n in walls or (n==gate and not open_) or n==b: continue
            if n in water and n not in br: continue
            ncr,nbr=cr,br
            if n in cr:
                t=(n[0]+dx,n[1]+dy)
                if t in walls or t in cr or t==gate or t==exit_ or t==b: continue
                if t in water and t not in br:
                    if not floating: continue
                    ncr=cr-{n}; nbr=br|{t}
                else:
                    ncr=(cr-{n})|{t}
            npl,ncr,nb,nd=bstep(n,ncr,nbr,b,d)
            ns=(npl,ncr,nbr,nb,nd)
            if ns not in seen:
                seen[ns]=(st,m); q.append(ns)
    return None

ROOMS = {
 'room1': [
  "  #########  ",
  "  #...#...#  ",
  "  #.P.B..o#  ",
  "  #..#.B..## ",
  "  #.......GE ",
  "  #..o....## ",
  "  #########  ",
 ],
 'room2': [
  "##############  ",
  "#....#~~.....#  ",
  "#.P.B.~~..o..#  ",
  "#..B..~~.....## ",
  "#...B.~~..B...GE",
  "#.....~~...o.## ",
  "##############  ",
 ],
 'room3': [
  "##########     ",
  "#P..#..o.#     ",
  "#.B...B..GE    ",
  "#..#B..#.#     ",
  "#.....##.#     ",
  "#####.######   ",
  "#A.........oo# ",
  "###############",
 ],
}
if __name__=='__main__':
    for name,rows in ROOMS.items():
        s=solve(rows); print(name, 'SOLVABLE' if s else 'UNSOLVABLE', len(s) if s else '', s or '')
        if name=='room2': print('  without floating:', solve(rows,False))
        if name=='room3': print('  without the banana:', solve(rows,banana=False))
