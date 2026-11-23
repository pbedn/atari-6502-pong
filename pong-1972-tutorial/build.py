"""Assemble the five Pong 1972 lesson ROMs with the workspace builder."""

from pathlib import Path
import runpy


HERE = Path(__file__).resolve().parent
LESSONS = ("01-frame", "02-paddles", "03-ball", "04-match", "05-menu-and-cpu")


def main():
    assemble = runpy.run_path(str(HERE.parent / "build_roms.py"))["assemble"]
    for lesson in LESSONS:
        source = HERE / lesson / f"{lesson}.asm"
        image, _ = assemble(source)
        rom = source.with_suffix(".bin")
        rom.write_bytes(image)
        print(f"{rom.relative_to(HERE)}: {len(image)} bytes")


if __name__ == "__main__":
    main()
