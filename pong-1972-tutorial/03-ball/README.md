# 03. Animate the ball and detect paddle hits

[Assembly source](03-ball.asm) / [Open the ROM in Stella](03-ball.bin)

## Walk through the code

1. Add `ballx`, `bally`, `dx`, and `dy` to RAM. Each frame, clear carry
   with `CLC` and use `ADC` to add each velocity to its coordinate. In an
   eight bit byte, `$FF` represents minus one.
2. At the top and bottom of the play area, `ReverseY` flips the vertical
   heading. `EOR #$FF` inverts all eight bits and adding one gives the
   negated value. `ReverseX` applies the same operation horizontally.
3. Place the TIA ball using `PositionX` with X set to 4. Set bit 1 of
   `ENABL` on the ball's two logical rows. With the width set in `CTRLPF`,
   that produces a small square in Stella's normal display proportions.
4. Check for a paddle only as the ball crosses that paddle's X position
   heading toward it. Compare its Y position with the paddle, including
   one extra row for the ball's height. A hit branches to `ReverseX` while the
   ball is still in front of the paddle.

## Try it

With the pads centered, watch the ball bounce at the edge after a miss.
Move a paddle into its path and check that the reversal happens in front of
the paddle. The side walls keep the drill running. For a simple exercise,
insert `LDA #0` between `STA dx` and `STA dy` in `Start`. Line up both
paddles for a flat volley.

[Previous lesson](../02-paddles/README.md) / [Next lesson](../04-match/README.md)
