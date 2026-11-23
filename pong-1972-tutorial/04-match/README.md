# 04. Turn the drill into a match

[Assembly source](04-match.asm) / [Open the ROM in Stella](04-match.bin)

## Walk through the code

1. Replace a side wall bounce with `PointLeft` or `PointRight`. Increment
   the opponent's score and call `Serve`, which puts the ball back near the
   middle and inserts a short pause. At 11 points, set `winner` to stop
   the match update and blink that side's score.
2. Add three return angles in `CheckPaddle`. The vertical contact offset
   sets `dy` to minus one, zero, or one. `RallyPace` skips one update in
   four until the rally has three returns.
3. Replace the 22 blank lines at the top with 21 score lines and one blank
   separator. Each digit row is three scanlines tall. Multiplying the score
   by eight with three `ASL` instructions indexes that score's glyph.
   In `ScoreLine`, write `PF2` once for the left side and again when the
   beam passes the middle. The two tables pack bits in opposite orders
   because the playfield is reflected.
4. `Tone` sets an audio pitch and volume. Each frame, `TickAudio` counts
   down and eventually clears volume. The console's Reset switch resets
   the match.

## Try it

Use **Up / Down** and **Y / H**. Let the ball pass a paddle and watch the
opposite score advance. Leave the paddles alone to see the winner blink
at 11. Press **F2** to return to 0–0. For an exercise, replace the two
`CMP #11` instructions in the point routines with `CMP #3` for a quick match.

[Previous lesson](../03-ball/README.md) / [Next lesson](../05-menu-and-cpu/README.md)
