import logging
import uuid
from enum import IntEnum

import attr

from .utils import *

logger = logging.getLogger(__name__)


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
            args = infostring_decode(buf.decode(UTF_8))
            for k in ("gameversion", "sv_maxclients", "clients", "bots", "protocol"):
                args[k] = int(args[k])
            ret = SVGetInfoResponse(**args)


@attr.s(auto_attribs=True, frozen=True, slots=True)
class CLConnect(Writable):
    info: dict = {"protocol": "darkplaces 3", "protocols": "DP7"}

    def encode(self) -> bytes:
        return HEADER + b"connect" + infostring_encode(self.info).encode(UTF_8)


class NetFlag(IntEnum):
    DATA = 1 << 0
    ACK = 1 << 1
    NAK = 1 << 2
    EOM = 1 << 3
    UNRELIABLE = 1 << 4

    CRYPTO0 = 1 << 12
    CRYPTO1 = 1 << 13
    CRYPTO2 = 1 << 14
    CTL = 1 << 15


@attr.s(auto_attribs=True, frozen=False, slots=True)
class Packet(Writable):
    flags: int
    messages: List[Writable]
    seq: Optional[int] = None

    def encode(self) -> bytes:
        assert self.seq is not None
        payload = b"".join(map(lambda it: it.encode(), self.messages))
        return bytes(
            ByteWriter()
                .u16_be(self.flags)
                .u16_be(8 + len(payload))
                .u32_be(self.seq)
        ) + payload


@attr.s(auto_attribs=True, frozen=True, slots=True)
class SVSignonReply(Readable):
    state: int


@attr.s(auto_attribs=True, frozen=True, slots=True)
class NOP(Writable):
    def encode(self) -> bytes:
        return bytes(
            ByteWriter()
                .u8(1)
        )


@attr.s(auto_attribs=True, frozen=True, slots=True)
class CLStringCommand(Writable):
    cmd: str

    def encode(self) -> bytes:
        return bytes(
            ByteWriter()
                .u8(4)
                .string(self.cmd)
        )


@attr.s(auto_attribs=True, frozen=True, slots=True)
class CLAckDownloadData(Writable):
    start: int
    size: int

    def encode(self) -> bytes:
        return bytes(
            ByteWriter()
                .u8(51)
                .u32(self.start)
                .u16(self.size)
        )


SVMessage = Union[
    SVGetInfoResponse,
    SVSignonReply,
]


@attr.s(auto_attribs=True, frozen=False, slots=True)
class SequenceInfo:
    recv_r: int = 0
    recv_u: int = 0
    send_u: int = 0


@generator
def sv_parse(reply: Callable[[Connection, Packet], None] = lambda _conn, _data: None) -> Generator[
    Tuple[Optional[SVMessage], SequenceInfo], Tuple[Connection, bytes], None
]:
    ret: Optional[SVMessage] = None

    getinfo_response = b"infoResponse\n"

    seqs = SequenceInfo()
    recvbuf = bytearray()

    while True:
        conn: Connection
        buf: bytes
        conn, buf = yield ret, seqs
        ret = None
        if buf.startswith(HEADER):
            buf = buf[len(HEADER):]
            if buf.startswith(getinfo_response):
                buf = buf[len(getinfo_response):]
                ret = SVGetInfoResponse.decode().send(buf)
                continue
            logger.debug(f"unhandled connectionless msg: {buf}")
            continue

        r = ByteReader(buf)
        flags = r.u16_be()
        size = r.u16_be()

        if (flags & NetFlag.CTL) or size != len(buf):
            logger.debug("discard")
            continue

        seq = r.u32_be()
        buf = buf[8:]
        logger.debug(f"seq={seq}, len={size}, flags={bin(flags)}")

        if flags & NetFlag.UNRELIABLE:
            if seq < seqs.recv_u:
                continue  # old
            if seq > seqs.recv_u:
                pass  # dropped a few packets
            seqs.recv_u = seq + 1
        elif flags & NetFlag.ACK:
            continue  # todo
        elif flags & NetFlag.DATA:
            reply(conn, Packet(NetFlag.ACK, [], seq))
            if seq != seqs.recv_r:
                continue
            seqs.recv_r += 1
            recvbuf.extend(buf)
            if not (flags & NetFlag.EOM):
                continue
            r = ByteReader(bytes(recvbuf))
            recvbuf.clear()

        logger.debug(f"game: {r.underflow()}")

        while True:
            if not len(r.underflow()):
                break
            cmd = r.u8()
            if cmd == 1:  # svc_nop
                logger.debug("<-- server to client keepalive")
                ret = NOP()
            elif cmd == 2:  # svc_disconnect
                logger.debug("Server disconnected")
            elif cmd == 5:  # svc_setview
                ent = r.u16()
            elif cmd == 7:  # svc_time
                time = r.f32()
            elif cmd == 8:  # svc_print
                s = r.string()
                logger.info(f"print: {repr(s)}")
            elif cmd == 9:  # svc_stufftext
                s = r.string()
                logger.debug(f"stufftext: {repr(s)}")
            elif cmd == 11:  # svc_serverinfo
                protocol = r.u32()
                logger.debug(f"proto: {protocol}")
                maxclients = r.u8()
                logger.debug(f"maxclients: {maxclients}")
                game = r.u8()
                logger.debug(f"game: {protocol}")
                mapname = r.string()
                logger.debug(f"mapname: {mapname}")
                while True:
                    model = r.string()
                    if model == "":
                        break
                    logger.debug(f"model: {model}")
                while True:
                    sound = r.string()
                    if sound == "":
                        break
                    logger.debug(f"sound: {sound}")
            elif cmd == 23:  # svc_temp_entity
                break
            elif cmd == 25:  # svc_signonnum
                state = r.u8()
                ret = SVSignonReply(state)
            elif cmd == 32:  # svc_cdtrack
                track = r.u8()
                looptrack = r.u8()
            elif cmd == 50:  # svc_downloaddata
                start = r.u32()
                size = r.u16_be()
                data = r.u8_array(size)
                reply(conn, Packet(NetFlag.DATA | NetFlag.EOM, [CLAckDownloadData(start, size)]))
            elif cmd == 59:  # svc_spawnstaticsound2
                origin = (r.f32(), r.f32(), r.f32())
                soundidx = r.u16_be()
                vol = r.u8()
                atten = r.u8()
            else:
                logger.debug(f"unimplemented: {cmd}")
                r.skip(-1)
                break
        uflow = r.underflow()
        if len(uflow):
            logger.debug(f"underflow_1: {uflow}")
