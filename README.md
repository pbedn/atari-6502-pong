# Pong Game inspired by 70s Atari arcade classic

Two Atari 2600 games written in 6502 assembly and inspired by Atari's 1972
arcade Pong. Both use a black court, tall white paddles, a square ball, a
thin dashed center line, and numeric scores.

| Version | What happens on startup | Files |
| --- | --- | --- |
| **Pong 1972** | Starts a local two-player match immediately | [Source](pong-1972.asm) · [ROM](pong-1972.bin) |
| **Enhanced Pong** | Offers a menu for one player against the computer or two local players | [Source](pong.asm) · [ROM](pong.bin) |

[Stella screenshot](stella-preview.png) ·
[Atari's 1972 arcade flyer](https://flyers.arcade-museum.com/videogames/show/1885) ·
[Capture from a 1972 arcade board](https://www.youtube.com/watch?v=fiShX2pTz9A) ·
[Computer History Museum prototype](https://computerhistory.org/blog/50-years-of-fun-with-pong/)

## Play

Open either ROM in Stella. Use **Up / Down** for the left paddle and
**Y / H** for the right. Joysticks work in both controller ports.
In **Enhanced Pong**, use **Left / Right** to choose **1P** or **2P** and
press **Space** or **Fire** to start. In **1P**, the computer controls the
right paddle.

The upper, middle, and lower parts of each paddle send the ball up, straight,
or down. The ball speeds up after three consecutive returns. A missed return
gives the other player a point. The first player to **11** wins and their
score blinks. Press **F2** to restart the match in **Pong 1972** or return
to the menu in **Enhanced Pong**.

## Build

Run these commands in this directory with DASM on your PATH. Each command
produces a 4 KiB NTSC Atari 2600 cartridge.

```text
dasm pong-1972.asm -f3 -opong-1972.bin
dasm pong.asm -f3 -opong.bin
```
