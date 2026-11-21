"""Plays Blobb's puzzle rooms through gda (live, in the real game) and reports what happens.
Start a session first (tools/gda.sh start SCENE); this script only drives and reads it.
  python3 tools/playtest.py clearing    # both clearing rooms, by the known solutions
Every narration line seen is logged, so missing or odd text shows up in the output.
"""
import json, os, subprocess, sys, time

ENV = dict(os.environ)
ENV["PATH"] = os.path.expanduser("~/.local/bin") + ":" + ENV["PATH"]
ENV.setdefault("GDA_GODOT", os.path.expanduser("~/.local/bin/godot-gda"))
ENV["GDA_PROJECT"] = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENV.setdefault("DISPLAY", ":97")


def gda(*args):
    r = subprocess.run(["gda", *args, "--json"], capture_output=True, text=True, env=ENV)
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        raise RuntimeError(f"gda {' '.join(args)}: {r.stdout[:300]} {r.stderr[:300]}")


class Game:
    def __init__(self):
        self.root = gda("game", "tree", "--max-depth", "0")["root"]["path"]
        self.lines = []
        self.log = []

    def state(self):
        d = gda("game", "call", self.root, "--method", "debug_state")
        if "value" not in d:
            raise RuntimeError(f"debug_state: {d}")
        v = d["value"]
        line = v.get("line")
        if line and (not self.lines or self.lines[-1] != line):
            self.lines.append(line)
            print("   «" + line + "»")
        return v

    def key(self, k, hold=2):
        gda("input", "tap", "--key", k, "--hold-frames", str(hold))

    def action(self, a, hold=2):
        gda("input", "tap", "--action", a, "--hold-frames", str(hold))

    def hold(self, a, frames):
        ev = [{"type": "action", "physics_frame": 0, "action": a},
              {"type": "action", "physics_frame": frames, "action": a, "release": True}]
        gda("input", "sequence", "--events", json.dumps(ev))

    def free(self, timeout=60.0, busy_keys=("busy",)):
        """Advance narration until the player has control. Returns the state."""
        t0 = time.time()
        while time.time() - t0 < timeout:
            s = self.state()
            if not s.get("locked") and not any(s.get(k) for k in busy_keys):
                return s
            if s.get("waiting"):
                self.key("Space")
            time.sleep(0.25)
        raise TimeoutError(f"still locked after {timeout}s: {s}")

    def plan(self):
        return gda("game", "call", self.root, "--method", "debug_plan")["value"]

    def shot(self, name):
        path = os.path.join(ENV["GDA_PROJECT"], "build", "playtest", name + ".png")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        gda("screen", "capture", "--output", path)
        return path

    def errors(self):
        out = []
        for e in gda("diag", "errors").get("errors", []):
            m = e.get("message", "")
            if e.get("level") == "warning" and any(s in m for s in ("wd.xic", "V-Sync", "opposite anchors")):
                continue
            out.append(f"{e.get('level')}: {m} ({e.get('file')}:{e.get('line')})")
        return out


def note(msg):
    print("!! " + msg)


# ---------------------------------------------------------------- ch1 clearing (sokoban)

CLEAR_SOLUTIONS = ["RRRRLDDRDLLRRRURR", "DRRRLLUURDLDRRRLDDLULURRRRRRDRURDRRRR"]
KEYS = {"R": "right", "L": "left", "U": "up", "D": "down"}
STEP = {"R": (1, 0), "L": (-1, 0), "U": (0, -1), "D": (0, 1)}


def clearing(g):
    for room, sol in enumerate(CLEAR_SOLUTIONS):
        s = g.free()
        if s["room"] != room:
            note(f"expected room {room}, game is in room {s['room']}")
        print(f"room {room + 1}: start cell {s['cell']} crates {s['crates']}")
        i = 0
        tries = 0
        while i < len(sol):
            s = g.free()
            before = s["cell"]
            dx, dy = STEP[sol[i]]
            want = [before[0] + dx, before[1] + dy]
            for attempt in range(4):
                g.action(KEYS[sol[i]])
                time.sleep(0.3)
                s = g.free()  # a push can start a story beat (and the game may redo the push after it)
                if s["cell"] != before or s.get("room") != room or s.get("done"):
                    break
            if s.get("room") != room or s.get("done"):
                break
            if s["cell"] != want:
                g.shot(f"clearing_r{room + 1}_stuck_{i}")
                note(f"room {room + 1}: move {i} ({sol[i]}) from {before} ended at {s['cell']}, wanted {want}; {s}")
                return
            i += 1
        print(f"room {room + 1}: all {len(sol)} moves made")
        t0 = time.time()
        while time.time() - t0 < 30:  # the exit: narration, then the next room or the ending
            s = g.state()
            if s.get("room", room) != room or s.get("done"):
                break
            if s.get("waiting"):
                g.key("Space")
            time.sleep(0.3)
        else:
            note(f"room {room + 1}: solved but no next room after 30 s: {s}")
    g.shot("clearing_end")


# ---------------------------------------------------------------- ch2 mill (flow rooms)

def place(g, node, pos):
    """Puts a node at `pos` directly (game set). For testing the puzzle, not the swimming."""
    r = gda("game", "set", f"{g.root}/{node}", "--property", "position", "--value", f"{pos[0]},{pos[1]}")
    if not r.get("verified"):
        raise RuntimeError(f"couldn't place {node}: {r}")


def swim_to(g, target, cell):
    """Blobb to the control `cell`: placed in front of it (the swimming itself was checked by
    hand: strokes reach every control). True when that control is the one in reach."""
    for _ in range(3):
        place(g, "Player", target)
        time.sleep(0.1)
        if g.state().get("in_reach") == cell:
            return True
    return False


def mill(g):
    for room in range(3):
        s = g.free(busy_keys=("busy", "busy_room"))
        if s["room"] != room:
            note(f"expected room {room + 1}, game is in room {s['room'] + 1}")
        print(f"room {room + 1}: duck {s['duck']} goal {s['goal']}")
        plan = g.plan()
        if not plan["presses"]:
            print(f"room {room + 1}: no way yet (expected only in room 3, before 'backwards'); waiting")
            t0 = time.time()
            while not plan["presses"] and time.time() - t0 < 60:
                g.free(busy_keys=("busy", "busy_room"))
                time.sleep(1.0)
                plan = g.plan()
            if not plan["presses"]:
                note(f"room {room + 1}: still no solution after 60 s; reverse_allowed={g.state()['reverse_allowed']}")
                g.shot(f"mill_r{room + 1}_nosolution")
                return
        print(f"room {room + 1}: plan {len(plan['presses'])} presses")
        guard = 0
        while plan["presses"] and guard < 30:
            guard += 1
            c = plan["presses"][0]
            key = f"{c[0]},{c[1]}"
            if not swim_to(g, plan["targets"][key], c):
                g.shot(f"mill_r{room + 1}_cantreach")
                note(f"room {room + 1}: couldn't get control {c} in reach; {g.state()}")
                return
            before = g.state()
            g.action("advance")
            time.sleep(0.3)
            after = g.free(busy_keys=("busy", "busy_room"))
            if (after["spouts"], after["boards"]) == (before["spouts"], before["boards"]) and after["room"] == room:
                note(f"room {room + 1}: pressing {c} changed nothing")
            if after["room"] != room or after["done"]:
                break
            last, still = after["duck"], 0  # let the duck ride until it stops (the solver's model)
            for _ in range(40):
                time.sleep(0.25)
                s = g.state()
                if s["room"] != room or s["done"]:
                    break
                still = still + 1 if s["duck"] == last else 0
                last = s["duck"]
                if still >= 4:
                    break
            if s["room"] != room or s["done"]:
                break
            plan = g.plan()
            if not plan["presses"] and not s["solved"]:
                note(f"room {room + 1}: after pressing {c} the solver sees no way on (duck {s['duck']})")
        # the duck rides the streams to the goal; then story and the next room
        t0 = time.time()
        while time.time() - t0 < 60:
            s = g.state()
            if s["room"] != room or s["done"]:
                break
            if s.get("waiting"):
                g.key("Space")
            time.sleep(0.3)
        else:
            g.shot(f"mill_r{room + 1}_notsolved")
            note(f"room {room + 1}: all presses made but no next room after 60 s: duck {s['duck']} goal {s['goal']}")
            return
        print(f"room {room + 1}: done")
    t0 = time.time()
    try:
        while time.time() - t0 < 40:
            s = g.state()
            if s.get("waiting"):
                g.key("Space")
            time.sleep(0.4)
    except RuntimeError:
        pass  # the scene changed (the chapter card, then the title)


# ---------------------------------------------------------------- ch3 roofs (light bridges)
# Real inputs only: Blobb walks and jumps along the strict model's path. Physics runs at 120 Hz;
# he walks ~3.5 px per physics frame.

PX_PER_FRAME = 3.55


def call(g, method, *args):
    r = gda("game", "call", "--params-json", json.dumps({"node": g.root, "method": method, "args": list(args)}))
    if "value" not in r:
        raise RuntimeError(f"{method}: {r}")
    return r["value"]


def settle(g, t=4.0):
    t0 = time.time()
    while time.time() - t0 < t:
        s = g.state()
        if s.get("on_floor") and abs(s["velocity"][0]) < 1 and abs(s["velocity"][1]) < 1:
            return s
        time.sleep(0.15)
    return g.state()


def walk_to(g, x, tol=14.0):
    for _ in range(12):
        s = settle(g)
        dx = x - s["player"][0]
        if abs(dx) <= tol:
            return s
        g.hold("right" if dx > 0 else "left", max(2, min(160, int(abs(dx) / PX_PER_FRAME))))
    return g.state()


def jump_to(g, frm, to, jump_frames=60):
    """A jump from stand point frm to stand point to: jump held jump_frames, the direction held
    for as long as the horizontal distance takes at full speed."""
    dx = to[0] - frm[0]
    run = 16 if abs(dx) > 200 else 0   # a long jump: run to the edge of the roof first
    n = int(abs(dx) / PX_PER_FRAME)
    ev = [{"type": "action", "physics_frame": run, "action": "jump"},
          {"type": "action", "physics_frame": run + jump_frames, "action": "jump", "release": True}]
    if n > 0:
        d = "right" if dx > 0 else "left"
        ev += [{"type": "action", "physics_frame": 0, "action": d},
               {"type": "action", "physics_frame": n, "action": d, "release": True}]
    ev.sort(key=lambda e: e["physics_frame"])
    gda("input", "sequence", "--events", json.dumps(ev))


def go_to_cell(g, cell, label, room, max_moves=30):
    """Moves Blobb to stand in `cell` by the plan's path. Returns True on arrival (or when the
    room is over: reaching the goal moves the game on by itself)."""
    fails = 0
    fails_at_start = g.state().get("fails", 0)
    for _ in range(max_moves):
        s = g.state()
        if s["room"] != room or s["done"]:
            return True
        g.free(busy_keys=("busy", "busy_room"))
        s = settle(g)
        if s["room"] != room or s["done"]:
            return True
        plan = call(g, "debug_plan", *cell)
        path = plan["path"]
        if not path:
            g.shot(f"roofs_nopath_{label}")
            note(f"{label}: no path from {plan['from']} to {cell} (lamps {s['lamps']})")
            return False
        if len(path) == 1:
            walk_to(g, path[0]["stand"][0])
            return True
        a, b = path[0], path[1]
        up = a["surf"][1] - b["surf"][1]   # half cells; > 0 is up
        dxc = b["surf"][0] - a["surf"][0]
        walk_to(g, a["stand"][0])
        if up <= 0 and abs(dxc) <= 1 and fails == 0:
            walk_to(g, b["stand"][0])     # level, or stepping down / off
        else:
            jump_to(g, a["stand"], b["stand"], 60 if up > 1 or abs(dxc) > 1 else 30)
        s = settle(g)
        if s.get("fails", 0) > fails_at_start:
            print(f"   {label}: fell on {a['surf']} -> {b['surf']} (up {up}, dx {dxc}): a retell, the room starts over")
            while g.state().get("retelling"):
                time.sleep(0.3)
            return "fell"
        now = call(g, "debug_plan", *cell)["from"]
        if now == b["surf"]:
            fails = 0
            continue
        fails += 1
        print(f"   {label}: move {a['surf']} -> {b['surf']} ended at {now} (try {fails})")
        if s.get("room_changed") or fails > 4:
            g.shot(f"roofs_fail_{label}")
            note(f"{label}: can't make the move {a['surf']} -> {b['surf']} (up {up}, dx {dxc}); ends at {now}")
            return False
    return False


def roofs_room(g, room):
    s = g.free(busy_keys=("busy", "busy_room"))
    if s["room"] != room:
        note(f"expected room {room + 1}, game is in room {s['room'] + 1}")
    plan = call(g, "debug_plan")
    sol = plan["solution"]
    print(f"room {room + 1}: solution {sol}, goal {plan['goal']}, lamps {s['lamps']}")
    for i, c in enumerate(sol):
        r = go_to_cell(g, c, f"r{room + 1}_crank{i + 1}", room)
        if r is not True:
            return r
        s = settle(g)
        if s["crank_in_reach"] != c:
            note(f"room {room + 1}: standing at crank {c} but crank_in_reach is {s['crank_in_reach']}")
        before = s["lamps"]
        g.action("use")
        time.sleep(0.4)
        s = g.state()
        print(f"   turned {c}: lamps {before} -> {s['lamps']}")
        if s["lamps"] == before:
            note(f"room {room + 1}: turning {c} didn't change the lamps")
    return go_to_cell(g, plan["goal"], f"r{room + 1}_goal", room)


def roofs(g):
    for room in range(3):
        for attempt in range(4):
            r = roofs_room(g, room)
            if r != "fell":
                break
        if r is not True:
            return
        t0 = time.time()
        while time.time() - t0 < 40:
            s = g.state()
            if s["room"] != room or s["done"]:
                break
            if s.get("waiting"):
                g.key("Space")
            time.sleep(0.3)
        else:
            g.shot(f"roofs_r{room + 1}_notdone")
            note(f"room {room + 1}: at the goal but no next room after 40 s; solved={s['solved']} cell={s['cell']}")
            return
        print(f"room {room + 1}: done")
    t0 = time.time()
    try:
        while time.time() - t0 < 40:
            s = g.state()
            if s.get("waiting"):
                g.key("Space")
            time.sleep(0.4)
    except RuntimeError:
        pass  # the scene changed (on to the chase)


if __name__ == "__main__":
    g = Game()
    root = g.root
    {"clearing": clearing, "mill": mill, "roofs": roofs}[sys.argv[1]](g)
    for e in g.errors():
        note("engine " + e)
    print("lines seen:", len(g.lines))
