# 05. Add a title menu and a computer paddle

[Assembly source](05-menu-and-cpu.asm) / [Open the ROM in Stella](05-menu-and-cpu.bin)

## Walk through the code

1. Add `mode` in RAM. Zero means menu, one means solo, and two means local
   versus. `ResetGame` chooses the menu. `StartMatch` clears scores and
   serves while preserving the mode just chosen.
2. `UpdateMenu` checks the direction bits and then `INPT4`, the left fire
   button. `BIT` copies the register's bit 7 into the negative flag. A
   release clears `menuFireLock`, so holding Fire while resetting does
   not immediately start a match.
3. `WaitMenuBlank` draws the menu in place of the court. It waits the same
   vertical blank interval and displays 72 blank lines, 28 lines of
   lettering, and 92 more blank lines. The highlighted option has a
   brighter playfield color.
4. In solo mode, call `MoveComputer` instead of checking the right
   joystick. The computer compares its paddle center to a target. It tracks
   the ball coming toward it and returns toward center as the ball leaves.
   It only moves on alternate frames and ignores small differences at the
   target, so it can miss.

## Try it

Choose **1P** with **Left**, or **2P** with **Right**, and press **Space**.
In 1P, observe the right paddle during an incoming shot. Press **F2**, select
2P, and check that **Y / H** now control that paddle. For an exercise, change
the `AND #1` in `MoveComputer` to `AND #3`. The computer will move on one
frame in four.

[Previous lesson](../04-match/README.md) / [Tutorial index](../README.md)
