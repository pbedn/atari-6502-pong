# Build Pong 1972 in 6502 assembly

Start with a cartridge that draws two bands of color. Add one system at a
time until you reach the complete Pong 1972 game. Each checkpoint has its own
assembly file and a ready to load **4 KiB NTSC ROM**.

| Step | What you will see | Files |
| --- | --- | --- |
| 01 | A steady gray and blue screen | [Lesson](01-frame/README.md) / [Source](01-frame/01-frame.asm) / [ROM](01-frame/01-frame.bin) |
| 02 | Two controllable paddles and a dashed net | [Lesson](02-paddles/README.md) / [Source](02-paddles/02-paddles.asm) / [ROM](02-paddles/02-paddles.bin) |
| 03 | A moving ball that bounces off paddles and edges | [Lesson](03-ball/README.md) / [Source](03-ball/03-ball.asm) / [ROM](03-ball/03-ball.bin) |
| 04 | A complete two player match with scores and sound | [Lesson](04-match/README.md) / [Source](04-match/04-match.asm) / [ROM](04-match/04-match.bin) |
| 05 | A startup menu and a computer opponent | [Lesson](05-menu-and-cpu/README.md) / [Source](05-menu-and-cpu/05-menu-and-cpu.asm) / [ROM](05-menu-and-cpu/05-menu-and-cpu.bin) |

## How to follow the series

1. Open the checkpoint ROM in Stella and try the lesson's **Try it** steps.
2. Read the named routines in the assembly file. Labels give names to
   addresses. `#` marks an immediate value and `$` marks hexadecimal.
3. Make the exercise change, rebuild, and reload the same ROM. Keep a copy of
   the original ROM if you want to compare it with your edit.

Each assembly snapshot builds independently with DASM. For example, from
the `01-frame` directory:

```text
dasm 01-frame.asm -f3 -o01-frame.bin
```

The 2600 uses a 6507, which runs the 6502 instructions in these lessons. The
TIA handles video, sound, and fire buttons. The RIOT provides RAM, a timer,
and the joystick directions. The CPU writes the TIA as the display is drawn.
Atari's [Stella Programmer's Guide](https://www.atarihq.com/danb/files/stella.pdf)
is a handy register reference.

Checkpoint 04 matches the [standalone Pong 1972 ROM](../pong-1972.bin).
Checkpoint 05 shows how to add the menu and computer opponent from
[Enhanced Pong](../README.md).
