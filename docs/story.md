# Blobb: story bible

## The frame (never stated outright)

Two narrators are telling Blobb's story. They are an older person and a child, in a hospital at night. The player is not told this; it is revealed only gradually.

**Rules for all dialogue**
- **Equals, not parent and child.** Neither narrator looks after the other. No family words (mum, dad, son, "honey"...), and no bedtime or caretaker talk: no "it's late", sleep, tired, "your eyes say...", permission or promises handed down. They build the story together, half each.
- **Voices.** **O** (older; serif text with a crescent moon, left) is slow and wistful, speaks in slightly old-fashioned images ("in the days when the moss was still young"), forgets things, and has a dry humour. **Y** (younger; hand-written text with a round star, right) is quick, bossy and silly, and makes the rules ("Wrong half. In my half, Blobb jumps higher than trees"). Ideally a player could take them for two odd story-creatures until the hospital hints start.
- **Y has authority over the story.** When Y objects, the world changes: Blobb's colour, the style of the scene, monsters, branches, physics. O goes along with it, often with a wry remark.
- **No drawing words in dialogue.** The narrators never mention drawing, crayons, paper or pencils, since that would make them human too early. They ask for a "simple", "bright" or "dark" world; the crayon look is the game's own interpretation of that.
- **Never reveal WHO is in the hospital.** Hints (beeps, gaps, "will you be here tomorrow?") must fit either narrator being the one who is unwell, or both. Balance any crack in one voice with one in the other.
- **Blobb** is "he" / "han". He is green; this was settled in ch1, where O said purple and Y corrected it.
- Lines are written in **English**. Swedish (`sv:`) is optional for now; missing lines fall back to English. Translate once the story settles.
- **Tone arc.** Light-hearted and funny at first. Later chapters move toward childlike questions about what happens when we die. Hospital hints grow chapter by chapter; ch1 has only one quiet monitor beep at the very end.
- **Failure is a retell.** Y says "that's not what happened!" and the scene rewinds.

## Chapters

1. **The Other Side of the Forest** (done). Side-view forest platformer, then a top-down box-pushing puzzle in a clearing ("like a bird sees it").
   Beats: "Tell me something" → O's "somethings wander off, like cats" → O notices "the fuzzy one, over there" (a drawing or toy, left vague) → "I know half of his story; you tell the other half" (Y becomes co-narrator) → Blobb appears on blank paper → purple/green ("That was your half already") → a dark, realistic forest becomes a "simple" forest (shown in crayon) → "Blobb could jump super high" (jump unlocked) → pits with retells → a giant grumpy banana that Y shrinks → "the tree grew branches" → evening turns everything orange → "like a bird" fly-up into the top-down view → Blobb as a "fuzzy pancake" → crates and gate → a stream where "wooden crates float" (they become bridges) → Blobb rests → Y: "Will you be here tomorrow?" O: "...Where else would I be?" → "Tomorrow, Blobb learns to swim." → beep.
2. **Swimming.** An underwater, floaty swim in a pool, then a puzzle based on something humorous. Pays off the ch1 promise ("Can Blobb swim?" "Not yet.").
3. **The City.** A night city with street lamps: "the lights from the street lamps enhancing his yellow glow" makes Blobb yellow, then Y asks "Wait, wasn't he green?" and he turns green. Then a rooftop chase escaping birds, timed to rapid beeps from a hospital machine. The hospital's lit sign is visible in the distance. Fade to white, with O screaming "Help".
4. **Quiet.** Y: "Can we talk about a day when Blobb had less chasing, and more quiet?" A quiet, minimal climb up a mountain that ends under a starry sky. Y: "What do you think happens when we die?" O: "..."

## Blobb's forms (from the original drawing)

`assets/drawing.jpeg` shows Blobb seven ways. `tools/cut_drawing.py` cuts each one out of the photo into `assets/sprites/drawn_*.png`. Use the child's own figures wherever a form fits, rather than inventing new looks. In code: `BlobbSprite.set_form(name)`, in dialogue: `@blobb_form name` (`normal` goes back).

| Figure in the drawing | Asset | Used for |
|---|---|---|
| Classic: green fuzz, purple dot eyes, unibrow, blue feet | `drawn_blobb`, animated strips | Blobb's normal self (ch1 on) |
| Small, stretched oval flying diagonally, legs trailing | `blobb_superjump` strip (AI frames 24–32) | The story-unlocked big jump (ch1 "higher than trees") |
| Green with a dark spiky crown, angry brows, jagged teeth | `drawn_grumpy` | Blobb gets prickly when the banana pushes him (ch1 `banana_bump`) |
| Round green scribble, no face, no legs | `drawn_ball` | Blobb seen from above, "a fuzzy pancake" (ch1 clearing) |
| Big grey pencil scribble-burst | `drawn_scribble` | A retell: Y scribbles out what happened (ch1 falls) |
| "BLOBB" in blue crayon letters | `drawn_title` | Title screen |
| Blue Blobb, open purple mouth, dark legs | `drawn_blue` | **ch2 Swimming**: wet/cold Blobb underwater ("he went all blue") |
| Green blur with speed lines, face out in front | `drawn_dash` | **ch3 City**: the rooftop chase from the birds, at full speed |

Ideas for the rest: the scribble can also be weather (a storm cloud in ch3), and the ball form can roll down the ch4 mountain path.

## Style per scene

Mix styles freely, and let the narrators switch them: realistic, child's drawing, monochrome and so on. Backgrounds can change mid-scene when a narrator says so.
