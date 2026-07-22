#!/usr/bin/env python3
"""Simulate WalkEEG Flutter parser against firmware-like stream."""

from __future__ import annotations

import struct
import sys

MAGIC, VERSION, NUM_CH, FS, N = 0xA5, 0x01, 8, 2000, 20


def clamp(v: int) -> int:
    return max(0, min(32767, v))


def sample(sec: int, i: int, ch: int) -> int:
    return clamp(sec * 1000 + i + ch * 2000)


def build_frame(seq: int, sec: int, i: int) -> tuple[bytes, int, int]:
    buf = bytearray([MAGIC, VERSION])
    buf += struct.pack("<H", seq & 0xFFFF)
    buf.append(N)
    buf.append(0)
    for _ in range(N):
        for ch in range(NUM_CH):
            buf += struct.pack("<h", sample(sec, i, ch))
        i += 1
        if i >= FS:
            i = 0
            sec = (sec + 1) % 32
    return bytes(buf), sec, i


class Parser:
    def __init__(self) -> None:
        self.buf = bytearray()
        self.parsed = 0
        self.dropped = 0
        self.last_seq: int | None = None
        self.ch0: list[int] = []

    def feed(self, chunk: bytes) -> None:
        self.buf.extend(chunk)
        while True:
            try:
                start = self.buf.index(MAGIC)
            except ValueError:
                self.buf.clear()
                return
            if start:
                del self.buf[:start]
            if len(self.buf) < 6:
                return
            n = self.buf[4]
            flen = 6 + n * 16
            if n == 0 or flen > 6 + 30 * 16:
                del self.buf[0]
                continue
            if len(self.buf) < flen:
                return
            if self.buf[1] != VERSION:
                del self.buf[0]
                continue
            frame = bytes(self.buf[:flen])
            del self.buf[:flen]
            self._parse(frame)

    def _parse(self, frame: bytes) -> None:
        seq = struct.unpack_from("<H", frame, 2)[0]
        n = frame[4]
        if self.last_seq is not None:
            expected = (self.last_seq + 1) & 0xFFFF
            if seq != expected:
                self.dropped += (seq - expected) & 0xFFFF
        self.last_seq = seq
        self.parsed += 1
        off = 6
        for _ in range(n):
            (v,) = struct.unpack_from("<h", frame, off)
            self.ch0.append(v)
            off += NUM_CH * 2


def main() -> int:
    frames: list[bytes] = []
    sec = i = 0
    for seq in range(0, 200):
        if seq == 50:
            for _ in range(N):
                i += 1
                if i >= FS:
                    i = 0
                    sec = (sec + 1) % 32
            continue
        f, sec, i = build_frame(seq, sec, i)
        frames.append(f)

    blob = b"\xDE\xAD" + b"".join(frames)
    parser = Parser()
    pos = 0
    sizes = [17, 100, 53, 326, 200, 7, 512]
    si = 0
    while pos < len(blob):
        n = sizes[si % len(sizes)]
        parser.feed(blob[pos : pos + n])
        pos += n
        si += 1

    errors = []
    if parser.parsed != 199:
        errors.append(f"parsed={parser.parsed} expected 199")
    if parser.dropped != 1:
        errors.append(f"dropped={parser.dropped} expected 1")
    if parser.ch0[0] != 0:
        errors.append(f"ch0[0]={parser.ch0[0]} expected 0")
    if not (parser.ch0[10] > parser.ch0[0]):
        errors.append("ramp not increasing")

    if errors:
        print("FAIL e2e sim:")
        for e in errors:
            print(" -", e)
        return 1

    print("OK: e2e stream/parser simulation passed")
    print(f"  frames={parser.parsed} drops={parser.dropped} ch0_len={len(parser.ch0)}")
    print(f"  ch0 head={parser.ch0[:5]} ... tail={parser.ch0[-5:]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
