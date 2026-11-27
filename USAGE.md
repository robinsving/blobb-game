# Token usage log

Rough estimates, one line per work session. Not precise.

**Correction, 2026-11-27:** every row below was marked "local", which is wrong for the
competition's sense of the word. Claude Code runs as a tool on the local machine, but the
model itself (Sonnet 5) runs on Anthropic's servers — a cloud service — regardless of
where the CLI happens to run. None of this usage is "local" (that term is for something
like Ollama/LM Studio running a model on your own hardware). Every row is cloud.

| Date | Session | Where | Approx. tokens | Notes |
|---|---|---|---|---|
| 2026-11-17 | blobb-da (Claude Code) | cloud | ~63M in (62M cache reads, 0.8M cache writes), ~0.4M out (corrected 2026-11-18 from the session log; first estimate said ~6M) | ch2 mill fixes, all of ch3, beam-room solver fix |
| 2026-11-17–19 | comfyui-5b (asset generation) | cloud | ~17.6M in (16.9M cache reads, 0.72M cache writes, ~0.3k fresh), ~0.12M out (from the session log, 2026-11-17 to 11-19 only; earlier days of the same log were other work; the old estimate of ~3M in was ~6× too low; ComfyUI renders themselves use no tokens) | ch1–ch5 art: forest, river/millpond, ch3 poster/street/rooftops/props, ch4 dream_bg and mountain (plus redo), ch5 skies, summit, cliff_bg, ledges, holds, room |
| 2026-11-17–18 | blobb (Claude Code, same session continued) | cloud | ~110M in (109M cache reads, 0.76M cache writes, ~1k fresh), ~0.34M out (from the session log) | ch3 roof/chase fixes, ch4 pacing, all of ch5, puzzle hints and key prompts, StoryGate, test menu and play.sh, monitor beep; a hospital ambience tried and dropped |
| 2026-11-20–27 | blobb-c6 (Claude Code, same session continued) | cloud | ~169M in (167M cache reads, 2.5M cache writes, ~2k fresh), ~0.62M out (from the session log, counted 2026-11-27 afternoon) | save/Continue, crash notice, prickly Blobb, chapters run straight on, ch5 night-sky ending and sweep up, ch2 whirlpools and half-way streams, ch3 canals, ch4 weak hop, clamber, rock mountain and cave, ch5 arm, extra stairs and moon/star in the room, quit-time fixes, dialogue edits |
| 2026-11-21–27 | comfyui (asset generation, comfyui-f7) | cloud | ~53.3M in (52.1M cache reads, 1.2M cache writes), ~0.19M out (from the session log; may include some non-Blobb work) | ch5 moon and bright star, ch4 climb animation (redone without the arm), ch4 rock mountain with cave, other Blobb art requests |

**Authoritative total, 2026-11-27** (whole-session counts, including a subagent the rows
above missed — supersedes summing the per-session rows above):

| Session | Tokens |
|---|---|
| Blobb session 3eb060d0 | 364,406,840 |
| Blobb subagent (inside 3eb060d0) | 67,646 |
| comfyui session a04f5229 | 151,225,192 |
| **Total** | **515,699,678** |

All cloud, 0 local.
