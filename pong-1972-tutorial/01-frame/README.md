# 01. Draw the first frame

[Assembly source](01-frame.asm) / [Open the ROM in Stella](01-frame.bin)

## Walk through the code

1. The cartridge code starts at `$F000`. The reset vector at `$FFFC`
   contains the address of `Start`, so the CPU knows where to begin.
   `SEI` masks interrupts and `CLD` selects binary arithmetic.
2. `ClearTIA` uses X as an offset over the TIA write addresses. It clears the
   registers before the first frame. `STA WSYNC` then waits for the end of
   the current scanline.
3. At `Frame`, put 2 in `VSYNC` to set bit 1, wait three lines, then clear it.
   Wait another 37 lines with `VBLANK` still set. X counts the lines:
   `DEX` subtracts one and `BNE` repeats while X is nonzero.
4. Clear `VBLANK` and change `COLUBK` halfway through the 192 visible lines.
   Blank the display again for 30 lines of overscan. The frame totals
   `3 + 37 + 192 + 30 = 262` lines.

## Try it

Expect a gray upper half and a blue lower half, with a steady boundary.
Change the `TopLine` and `BottomLine` counters to 64 and 128, respectively.
The split should move up while the frame length stays the same.

[Next lesson](../02-paddles/README.md)
