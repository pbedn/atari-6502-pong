# 02. Draw and move two paddles

[Assembly source](02-paddles.asm) / [Open the ROM in Stella](02-paddles.bin)

## Walk through the code

1. Reserve bytes in RIOT RAM starting at `$80`. Keep the two vertical
   coordinates in `p0y` and `p1y`. Set the stack pointer with `TXS` before
   using `JSR` and `RTS`.
2. Call `ReadJoysticks` during vertical blank. `SWCHA` directions are
   active low: if `AND #$10` produces zero, the left player is pressing Up.
   Decrement their Y coordinate to move up. The comparisons before changing
   either coordinate keep the paddles inside the court.
3. Use `PositionX` during blanking to place the two TIA players and missile
   0. Each loop iteration subtracts 15 from the desired X position and
   takes five CPU cycles, or 15 color clocks. The remainder sets the fine
   motion value. The `RESP0,x` strobe sets the coarse position and `HMOVE`
   applies the correction. A RIOT timer leaves a predictable blanking budget
   for this work.
4. In `Court`, compute `row - paddleY`. If that fits in 0 through 10, use
   `$C0` as the player bitmap, which turns on the first two bits. Otherwise,
   use zero. Each row stays active for two scanlines. Missile 0 draws the net,
   with `ENAM0` switching it on and off as rows pass.

## Try it

Move the left paddle with **Up / Down** and the right with **Y / H**. Expect
them to stop short of the top and bottom. Change the two paddle bitmap
values from `$C0` to `$F0` and compare their width after rebuilding.

[Previous lesson](../01-frame/README.md) / [Next lesson](../03-ball/README.md)
