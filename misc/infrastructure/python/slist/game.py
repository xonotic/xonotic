import uuid

import attr

from .utils import *

HEADER = b"\xFF\xFF\xFF\xFF"


@attr.s(auto_attribs=True, frozen=True, slots=True)
class CLGetInfo(Writable):
    def encode(self) -> bytes:
        return HEADER + f"getinfo {uuid.uuid4()}".encode(UTF_8)


@attr.s(auto_attribs=True, frozen=True, slots=True)
class SVGetInfoResponse(Readable):
    gamename: str
    modname: str
    gameversion: int
    sv_maxclients: int
    clients: int
    bots: int
    mapname: str
    hostname: str
    protocol: int
    qcstatus: Optional[str]
    challenge: Optional[str]
    d0_blind_id: Optional[str] = None

    @classmethod
    @generator
    def decode(cls) -> Generator[Optional["SVGetInfoResponse"], bytes, None]:
        ret: Optional[SVGetInfoResponse] = None
        while True:
            buf: bytes
            buf = yield ret
            parts = buf.decode(UTF_8).split("\\")[1:]
            pairs = zip(*[iter(parts)] * 2)
            args = dict(pairs)
            for k in ("gameversion", "sv_maxclients", "clients", "bots", "protocol"):
                args[k] = int(args[k])
            ret = SVGetInfoResponse(**args)


SVMessage = Union[SVGetInfoResponse]


@generator
def sv_parse() -> Generator[Optional[SVMessage], bytes, None]:
    getinfo_response = b"infoResponse\n"
    ret: Optional[SVMessage] = None
    while True:
        buf: bytes
        buf = yield ret
        ret = None
        if buf.startswith(HEADER):
            buf = buf[len(HEADER):]
            if buf.startswith(getinfo_response):
                buf = buf[len(getinfo_response):]
                ret = SVGetInfoResponse.decode().send(buf)
                continue
