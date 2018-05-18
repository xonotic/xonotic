import ipaddress
from struct import Struct

import attr

from .utils import *


@attr.s(auto_attribs=True, frozen=True, slots=True)
class CLGetServersExt(Writable):
    game: str
    protocol: int

    def encode(self) -> bytes:
        return HEADER + f"getserversExt {self.game} {self.protocol} empty full ipv4 ipv6".encode(UTF_8)


@attr.s(auto_attribs=True, frozen=True, slots=True)
class SVGetServersExtResponse(Readable):
    @attr.s(auto_attribs=True, frozen=True, slots=True)
    class Server:
        addr: str
        port: int

    servers: List[Server]

    @classmethod
    @generator
    def decode(cls) -> Generator[Optional["SVGetServersExtResponse"], bytes, None]:
        end = SVGetServersExtResponse.Server("", 0)
        ipv4 = Struct(">4sH")
        ipv6 = Struct(">16sH")

        def servers() -> Iterator[SVGetServersExtResponse.Server]:
            offset = 0
            while True:
                h = buf[offset:offset + 1]
                offset += 1
                if h == b"":
                    return
                elif h == b"\\":
                    record = ipv4
                elif h == b"/":
                    record = ipv6
                else:
                    assert False, f"unknown record type: {h}"

                it = record.unpack_from(buf, offset)
                if record == ipv4:
                    addr, port = it
                    if addr == b"EOT\x00" and port == 0:
                        yield end
                        return
                    addr = ipaddress.IPv4Address(addr)
                    yield SVGetServersExtResponse.Server(addr=addr, port=port)
                elif record == ipv6:
                    addr, port = it
                    addr = ipaddress.IPv6Address(addr)
                    yield SVGetServersExtResponse.Server(addr=addr, port=port)
                offset += record.size

        chunks: List[List[SVGetServersExtResponse.Server]] = []
        ret: Optional[SVGetServersExtResponse] = None
        done = False
        while True:
            buf: bytes
            buf = yield ret
            if done:
                return
            chunk = list(servers())
            chunks.append(chunk)
            if chunk[-1] == end:
                chunk.pop()
                ret = SVGetServersExtResponse(servers=[x for l in chunks for x in l])
                done = True


SVMessage = Union[SVGetServersExtResponse]


@generator
def sv_parse() -> Generator[Optional[SVMessage], Tuple[Connection, bytes], None]:
    getservers_ext_response = b"getserversExtResponse"
    getservers_ext_gen: Optional[Generator[Optional[SVGetServersExtResponse], bytes, None]] = None
    ret: Optional[SVMessage] = None
    while True:
        buf: bytes
        _, buf = yield ret
        ret = None
        if buf.startswith(HEADER):
            buf = buf[len(HEADER):]
            if buf.startswith(getservers_ext_response):
                buf = buf[len(getservers_ext_response):]
                if not getservers_ext_gen:
                    getservers_ext_gen = SVGetServersExtResponse.decode()
                assert getservers_ext_gen
                ret = getservers_ext_gen.send(buf)
                if ret:
                    getservers_ext_gen = None
                continue
