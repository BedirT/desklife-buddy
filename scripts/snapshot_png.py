"""Minimal, dependency-free PNG operations for snapshot review artifacts.

SnapshotTesting emits 8-bit, non-interlaced RGB/RGBA PNGs. Keeping this codec
small and explicit lets the review controller run under system Python's
isolated mode instead of importing mutable user-site imaging packages.
"""

from __future__ import annotations

import binascii
import pathlib
import struct
import zlib
from dataclasses import dataclass
from functools import lru_cache


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
MAX_INPUT_BYTES = 32 * 1024 * 1024
MAX_PIXELS = 16_000_000
MAX_CHUNKS = 4_096


@dataclass(frozen=True)
class Image:
    width: int
    height: int
    pixels: bytes  # packed RGB


@lru_cache(maxsize=64)
def load(path: pathlib.Path) -> Image:
    content = path.read_bytes()
    if len(content) > MAX_INPUT_BYTES:
        raise ValueError(f"PNG exceeds snapshot review size limit: {path}")
    if not content.startswith(PNG_SIGNATURE):
        raise ValueError(f"not a PNG: {path}")

    width = height = channels = 0
    compressed = bytearray()
    offset = len(PNG_SIGNATURE)
    chunks = 0
    while offset + 12 <= len(content):
        chunks += 1
        if chunks > MAX_CHUNKS:
            raise ValueError(f"PNG contains too many chunks: {path}")
        length = struct.unpack(">I", content[offset : offset + 4])[0]
        kind = content[offset + 4 : offset + 8]
        payload = content[offset + 8 : offset + 8 + length]
        if offset + length + 12 > len(content):
            raise ValueError(f"truncated PNG: {path}")
        expected_crc = struct.unpack(">I", content[offset + 8 + length : offset + 12 + length])[0]
        if binascii.crc32(kind + payload) & 0xFFFFFFFF != expected_crc:
            raise ValueError(f"invalid PNG checksum: {path}")
        if kind == b"IHDR":
            width, height, depth, color, compression, filtering, interlace = struct.unpack(
                ">IIBBBBB", payload
            )
            if depth != 8 or color not in {2, 6} or compression or filtering or interlace:
                raise ValueError(f"unsupported snapshot PNG format: {path}")
            channels = 3 if color == 2 else 4
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            break
        offset += length + 12

    if width < 1 or height < 1 or channels == 0:
        raise ValueError(f"missing PNG header: {path}")
    if width > 8_192 or height > 8_192 or width * height > MAX_PIXELS:
        raise ValueError(f"PNG dimensions exceed snapshot review limits: {path}")
    if len(compressed) > MAX_INPUT_BYTES:
        raise ValueError(f"PNG payload exceeds snapshot review limit: {path}")
    stride = width * channels
    expected_size = height * (stride + 1)
    decompressor = zlib.decompressobj()
    raw = decompressor.decompress(bytes(compressed), expected_size + 1)
    if len(raw) > expected_size or decompressor.unconsumed_tail:
        raise ValueError(f"unexpected PNG payload size: {path}")
    raw += decompressor.flush(expected_size + 1 - len(raw))
    if len(raw) != expected_size or decompressor.unused_data or not decompressor.eof:
        raise ValueError(f"unexpected PNG payload size: {path}")

    decoded = bytearray(height * stride)
    source = 0
    for row in range(height):
        filter_type = raw[source]
        source += 1
        row_start = row * stride
        for column in range(stride):
            value = raw[source]
            source += 1
            left = decoded[row_start + column - channels] if column >= channels else 0
            above = decoded[row_start - stride + column] if row else 0
            upper_left = (
                decoded[row_start - stride + column - channels]
                if row and column >= channels
                else 0
            )
            if filter_type == 0:
                result = value
            elif filter_type == 1:
                result = value + left
            elif filter_type == 2:
                result = value + above
            elif filter_type == 3:
                result = value + ((left + above) // 2)
            elif filter_type == 4:
                result = value + _paeth(left, above, upper_left)
            else:
                raise ValueError(f"unsupported PNG row filter: {filter_type}")
            decoded[row_start + column] = result & 0xFF

    if channels == 3:
        pixels = bytes(decoded)
    else:
        pixels_buffer = bytearray(width * height * 3)
        for pixel in range(width * height):
            source = pixel * 4
            target = pixel * 3
            alpha = decoded[source + 3]
            for channel in range(3):
                pixels_buffer[target + channel] = (
                    decoded[source + channel] * alpha + 142 * (255 - alpha)
                ) // 255
        pixels = bytes(pixels_buffer)
    return Image(width, height, pixels)


def encode(image: Image) -> bytes:
    stride = image.width * 3
    rows = b"".join(
        b"\x00" + image.pixels[offset : offset + stride]
        for offset in range(0, len(image.pixels), stride)
    )
    header = struct.pack(">IIBBBBB", image.width, image.height, 8, 2, 0, 0, 0)
    return PNG_SIGNATURE + _chunk(b"IHDR", header) + _chunk(
        b"IDAT", zlib.compress(rows, level=9)
    ) + _chunk(b"IEND", b"")


def resize(image: Image, max_width: int) -> Image:
    if image.width <= max_width:
        return image
    target_height = max(1, round(image.height * max_width / image.width))
    output = bytearray(max_width * target_height * 3)
    for y in range(target_height):
        source_y = min(image.height - 1, y * image.height // target_height)
        for x in range(max_width):
            source_x = min(image.width - 1, x * image.width // max_width)
            source = (source_y * image.width + source_x) * 3
            target = (y * max_width + x) * 3
            output[target : target + 3] = image.pixels[source : source + 3]
    return Image(max_width, target_height, bytes(output))


def crop(image: Image, box: tuple[int, int, int, int]) -> Image:
    left, top, right, bottom = box
    width = max(1, right - left)
    height = max(1, bottom - top)
    rows = []
    for y in range(top, bottom):
        start = (y * image.width + left) * 3
        rows.append(image.pixels[start : start + width * 3])
    return Image(width, height, b"".join(rows))


def compare(before: Image, after: Image, visible_delta: int) -> tuple[dict, Image]:
    if (before.width, before.height) != (after.width, after.height):
        return {
            "resized": True,
            "beforeDims": f"{before.width}x{before.height}",
            "afterDims": f"{after.width}x{after.height}",
            "visibleFraction": 1.0,
            "anyFraction": 1.0,
            "maxDelta": 1.0,
            "bbox": None,
        }, after

    total = before.width * before.height
    visible = any_changed = peak = 0
    min_x, min_y = before.width, before.height
    max_x = max_y = -1
    output = bytearray(total * 3)
    old_pixels = before.pixels
    new_pixels = after.pixels
    for pixel in range(total):
        offset = pixel * 3
        old_red, old_green, old_blue = old_pixels[offset : offset + 3]
        new_red, new_green, new_blue = new_pixels[offset : offset + 3]
        delta = max(
            abs(old_red - new_red),
            abs(old_green - new_green),
            abs(old_blue - new_blue),
        )
        peak = max(peak, delta)
        if delta:
            any_changed += 1
        if delta > visible_delta:
            visible += 1
            x, y = pixel % before.width, pixel // before.width
            min_x, min_y = min(min_x, x), min(min_y, y)
            max_x, max_y = max(max_x, x), max(max_y, y)
            strength = min(delta / 96.0, 1.0)
            hot = (
                round(255 * (1 - strength) + 214 * strength),
                round(170 * (1 - strength) + 40 * strength),
                round(40 * (1 - strength) + 160 * strength),
            )
            output[offset : offset + 3] = bytes(hot)
        else:
            gray = (new_red + new_green + new_blue) // 3
            pale = round(gray * 0.35 + 255 * 0.65)
            output[offset : offset + 3] = bytes((pale, pale, pale))

    bbox = None if max_x < 0 else [min_x, min_y, max_x + 1, max_y + 1]
    return {
        "resized": False,
        "beforeDims": f"{before.width}x{before.height}",
        "afterDims": f"{after.width}x{after.height}",
        "visibleFraction": visible / total,
        "anyFraction": any_changed / total,
        "maxDelta": peak / 255.0,
        "bbox": bbox,
    }, Image(before.width, before.height, bytes(output))


def _paeth(left: int, above: int, upper_left: int) -> int:
    estimate = left + above - upper_left
    distances = (abs(estimate - left), abs(estimate - above), abs(estimate - upper_left))
    return (left, above, upper_left)[distances.index(min(distances))]


def _chunk(kind: bytes, payload: bytes) -> bytes:
    checksum = binascii.crc32(kind + payload) & 0xFFFFFFFF
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", checksum)
