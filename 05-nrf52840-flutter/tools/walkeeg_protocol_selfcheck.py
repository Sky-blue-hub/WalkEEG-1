#!/usr/bin/env python3
"""Offline WalkEEG protocol + ramp-signal self-check (no hardware required).

Validates:
  - frame layout (magic/version/seq/n/payload LE)
  - ramp algorithm matches firmware (sec*1000+i+ch*2000, clamp 0..32767)
  - N=20 frame length = 326
"""

from __future__ import annotations

import struct
import sys


MAGIC = 0xA5
VERSION = 0x01
NUM_CH = 8
FS = 2000
DEFAULT_N = 20


def clamp(v: int) -> int:
    return max(0, min(32767, v))


def sample_at(sec: int, i: int, ch: int) -> int:
    return clamp(sec * 1000 + i + ch * 2000)


def build_frame(seq: int, n: int, start_sec: int, start_i: int) -> bytes:
    buf = bytearray()
    buf.append(MAGIC)
    buf.append(VERSION)
    buf += struct.pack("<H", seq & 0xFFFF)
    buf.append(n)
    buf.append(0)  # flags

    sec, i = start_sec, start_i
    for _ in range(n):
        for ch in range(NUM_CH):
            buf += struct.pack("<h", sample_at(sec, i, ch))
        i += 1
        if i >= FS:
            i = 0
            sec = (sec + 1) % 32
    return bytes(buf)


def parse_frame(frame: bytes) -> tuple[int, int, list[list[int]]]:
    assert frame[0] == MAGIC
    assert frame[1] == VERSION
    seq = struct.unpack_from("<H", frame, 2)[0]
    n = frame[4]
    assert len(frame) == 6 + n * NUM_CH * 2
    channels: list[list[int]] = [[] for _ in range(NUM_CH)]
    off = 6
    for _ in range(n):
        for ch in range(NUM_CH):
            (v,) = struct.unpack_from("<h", frame, off)
            channels[ch].append(v)
            off += 2
    return seq, n, channels


def main() -> int:
    errors: list[str] = []

    # Frame length
    f = build_frame(0, DEFAULT_N, 0, 0)
    if len(f) != 6 + DEFAULT_N * 16:
        errors.append(f"bad length: {len(f)}")

    # Second 0 first sample
    seq, n, chs = parse_frame(f)
    if chs[0][0] != 0 or chs[7][0] != 7:
        errors.append(f"sec0 start mismatch: ch0={chs[0][0]} ch7={chs[7][0]}")

    # Near end of second 31 (overflow clamp)
    # i=1999, base=31000+1999=32999 -> clamp 32767
    f2 = build_frame(1, 1, 31, 1999)
    _, _, chs2 = parse_frame(f2)
    if chs2[0][0] != 32767:
        errors.append(f"clamp fail: got {chs2[0][0]}")

    # Mid second 1: i=0 -> base=1000
    f3 = build_frame(2, 1, 1, 0)
    _, _, chs3 = parse_frame(f3)
    if chs3[0][0] != 1000 or chs3[3][0] != 1003:
        errors.append(f"sec1 mismatch: {chs3[0][0]}, {chs3[3][0]}")

    # Sticky packet: garbage + two frames
    sticky = b"\x00\x11" + f + f2
    # crude resync like Flutter
    idx = sticky.index(bytes([MAGIC]))
    chunk = sticky[idx:]
    flen = 6 + chunk[4] * 16
    p1 = chunk[:flen]
    p2 = chunk[flen:]
    s1, _, _ = parse_frame(p1)
    s2, _, _ = parse_frame(p2)
    if s1 != 0 or s2 != 1:
        errors.append(f"sticky seq fail: {s1},{s2}")

    if errors:
        print("FAIL:")
        for e in errors:
            print(" -", e)
        return 1

    print("OK: WalkEEG packet + ramp self-check passed")
    print(f"  default frame len = {len(f)} (N={DEFAULT_N})")
    print(f"  sec0: CH0={chs[0][0]}.. CH7 first={chs[7][0]}")
    print(f"  sec31 i=1999 clamped CH0={chs2[0][0]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
