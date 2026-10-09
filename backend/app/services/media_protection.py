"""حماية الوسائط — Watermarking (LSB) + بصمة إدراكية (aHash)

- embed_watermark: دمج حمولة JSON خفية في البتات الأدنى للصورة (PNG فقط —
  غير مفقودة عند الحفظ lossless).
- extract_watermark: استخراج الحمولة — إثبات مصدر/مسار الصورة إذا نُشرت.
- perceptual_hash: بصمة aHash مقاومة للتعديلات البسيطة (قياس/سطوع) —
  تُسجل في السجل الوطني لكشف النشر اللاحق.
"""
import hashlib
import io
import json

from PIL import Image

_MAGIC = b"NAPX"
_PHASH_SIZE = 8


def _bits_from_bytes(data: bytes):
    for byte in data:
        for i in range(7, -1, -1):
            yield (byte >> i) & 1


def _bits_to_bytes(bits: list[int]) -> bytes:
    out = bytearray()
    for i in range(0, len(bits) - 7, 8):
        byte = 0
        for bit in bits[i : i + 8]:
            byte = (byte << 1) | bit
        out.append(byte)
    return bytes(out)


def embed_watermark(image_bytes: bytes, payload: dict) -> bytes:
    """دمج الحمولة في LSB — يرفع ValueError إذا الصورة أصغر من الحمولة"""
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    stream = _MAGIC + len(data).to_bytes(4, "big") + data

    bits = list(_bits_from_bytes(stream))
    capacity = image.width * image.height * 3
    if len(bits) > capacity:
        raise ValueError("الصورة أصغر من أن تحمل البصمة")

    pixels = image.load()
    index = 0
    for y in range(image.height):
        for x in range(image.width):
            if index >= len(bits):
                break
            r, g, b = pixels[x, y][:3]
            channels = [r, g, b]
            for c in range(3):
                if index < len(bits):
                    channels[c] = (channels[c] & 0xFE) | bits[index]
                    index += 1
            pixels[x, y] = (channels[0], channels[1], channels[2])
        if index >= len(bits):
            break

    output = io.BytesIO()
    image.save(output, format="PNG")
    return output.getvalue()


def extract_watermark(image_bytes: bytes) -> dict | None:
    """استخراج البصمة — None إذا لا توجد بصمة NAP-EX أو كانت تالفة"""
    try:
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    except Exception:
        return None

    pixels = image.load()
    capacity = image.width * image.height * 3

    def collect(count: int, offset: int) -> list[int]:
        bits: list[int] = []
        index = 0
        for y in range(image.height):
            for x in range(image.width):
                r, g, b = pixels[x, y][:3]
                for channel in (r, g, b):
                    if index >= offset + count:
                        return bits
                    if index >= offset:
                        bits.append(channel & 1)
                    index += 1
        return bits

    header_bits = collect(64, 0)
    if len(header_bits) < 64:
        return None
    header = _bits_to_bytes(header_bits)
    if header[:4] != _MAGIC:
        return None

    length = int.from_bytes(header[4:8], "big")
    if length <= 0 or length > capacity // 8:
        return None
    payload_bits = collect(length * 8, 64)
    try:
        return json.loads(_bits_to_bytes(payload_bits).decode("utf-8"))
    except Exception:
        return None


def perceptual_hash(image_bytes: bytes) -> str:
    """aHash — بصمة 64 بت مقاومة للقياس والسطوع"""
    image = Image.open(io.BytesIO(image_bytes)).convert("L").resize(
        (_PHASH_SIZE, _PHASH_SIZE)
    )
    pixels = list(image.getdata())
    average = sum(pixels) / len(pixels)
    bits = "".join("1" if p > average else "0" for p in pixels)
    return f"{int(bits, 2):016x}"


def hamming_distance(a: str, b: str) -> int:
    """مسافة هامينغ بين بصمتين — ≤ 8 يعتبر تطابقاً محتملاً"""
    return bin(int(a, 16) ^ int(b, 16)).count("1")


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()
