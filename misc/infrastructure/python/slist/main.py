#!/usr/bin/env python3
import logging

from . import game
from . import master
from .utils import *

logger = logging.getLogger(__name__)


def main():
    import socket

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    connections: Dict[Connection, Union[
        Generator[Optional[master.SVMessage], Tuple[Connection, bytes], None],
        Generator[Tuple[Optional[game.SVMessage], game.SequenceInfo], Tuple[Connection, bytes], None],
    ]] = {}
    count_inforesponse = 0

    q_master = master.CLGetServersExt(game="Xonotic", protocol=3)
    conn = (socket.gethostbyname("dpmaster.deathmask.net"), 27950)
    connections[conn] = master.sv_parse()
    sock.sendto(q_master.encode(), conn)
    while True:
        logger.debug("recv(...)")
        try:
            data, conn = sock.recvfrom(1400)
        except KeyboardInterrupt:
            break
        logger.debug(f"recv({conn}): {data}")
        msg = connections[conn].send((conn, data))
        if isinstance(msg, tuple):
            msg = msg[0]
        if msg:
            logger.info(f"recv({conn}): {msg}")
            if isinstance(msg, master.SVGetServersExtResponse):
                logger.info(f"servers: {len(msg.servers)}")
                for srv in msg.servers:
                    conn = (str(srv.addr), srv.port)
                    q_server = game.CLGetInfo()
                    connections[conn] = game.sv_parse()
                    try:
                        sock.sendto(q_server.encode(), conn)
                    except socket.gaierror:
                        pass
            if isinstance(msg, game.SVGetInfoResponse):
                count_inforesponse += 1
                logger.info(f"status-{count_inforesponse}: {msg}")


if __name__ == "__main__":
    main()
