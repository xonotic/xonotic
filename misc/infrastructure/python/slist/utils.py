from functools import wraps
from typing import *

UTF_8 = "utf-8"


class Readable:
    @classmethod
    def decode(cls) -> Generator[Optional[object], bytes, None]:
        raise NotImplementedError


class Writable:
    def encode(self) -> bytes:
        raise NotImplementedError


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
