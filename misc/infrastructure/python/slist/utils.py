from functools import wraps
from typing import *

UTF_8 = "utf-8"


def generator(f):
    O = TypeVar("O")
    I = TypeVar("I")
    R = TypeVar("R")

    def prepare(g: Generator[O, I, R]) -> Generator[O, I, R]:
        next(g)
        return g

    @wraps(f)
    def w(*args, **kwargs):
        return prepare(f(*args, **kwargs))

    return w


class Readable:
    @classmethod
    def decode(cls) -> Generator[Optional[object], bytes, None]:
        raise NotImplemented


class Writable:
    def encode(self) -> bytes:
        raise NotImplemented


class ByteReader:
    __slots__ = (
        "_buf",
        "_ptr",
    )

    def __init__(self, buf: bytes) -> None:
        self._buf = buf
        self._ptr = 0

    def underflow(self) -> bytes:
        return self._buf[self._ptr:]

    def skip(self, n: int) -> None:
        self._ptr += n

    def u8(self) -> int:
        ret = self._buf[self._ptr]
        self.skip(1)
        return ret

    def u8_array(self, n: int) -> bytes:
        ret = self._buf[self._ptr:self._ptr + n]
        self.skip(n)
        return ret

    def u16(self) -> int:
        ret = 0
        ret |= self.u8() << 0
        ret |= self.u8() << 8
        return ret

    def u16_be(self) -> int:
        ret = 0
        ret |= self.u8() << 8
        ret |= self.u8() << 0
        return ret

    def u32(self) -> int:
        ret = 0
        ret |= self.u8() << 0
        ret |= self.u8() << 8
        ret |= self.u8() << 16
        ret |= self.u8() << 24
        return ret

    def u32_be(self) -> int:
        ret = 0
        ret |= self.u8() << 24
        ret |= self.u8() << 16
        ret |= self.u8() << 8
        ret |= self.u8() << 0
        return ret

    def f32(self) -> float:
        import struct
        return struct.unpack("<f", self.u8_array(4))[0]

    def string(self) -> str:
        arr = bytearray()
        while True:
            b = self.u8()
            if b == 0:
                break
            arr.append(b)
        return arr.decode(UTF_8)


class ByteWriter:
    __slots__ = (
        "_buf",
    )

    def __init__(self):
        self._buf: List[bytes] = []

    def __bytes__(self):
        return b"".join(self._buf)

    def u8(self, it: int) -> "ByteWriter":
        self._buf.append(it.to_bytes(1, "little"))
        return self

    def u16(self, it: int) -> "ByteWriter":
        self._buf.append(it.to_bytes(2, "little"))
        return self

    def u16_be(self, it: int) -> "ByteWriter":
        self._buf.append(it.to_bytes(2, "big"))
        return self

    def u32(self, it: int) -> "ByteWriter":
        self._buf.append(it.to_bytes(4, "little"))
        return self

    def u32_be(self, it: int) -> "ByteWriter":
        self._buf.append(it.to_bytes(4, "big"))
        return self

    def f32(self, it: float) -> "ByteWriter":
        import struct
        self._buf.append(struct.pack("<f", it))
        return self

    def string(self, it: str) -> "ByteWriter":
        self._buf.append(it.encode(UTF_8))
        self._buf.append(b"\x00")
        return self


Connection = Tuple[str, int]

HEADER = b"\xFF\xFF\xFF\xFF"


def infostring_decode(s: str) -> dict:
    parts = s.split("\\")[1:]
    pairs = zip(*[iter(parts)] * 2)
    return dict(pairs)


def infostring_encode(d: dict) -> str:
    return "".join(f"\\{k}\\{v}" for k, v in d.items())
