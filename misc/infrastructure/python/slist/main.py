#!/usr/bin/env python3
import logging
from typing import *

from . import game
from . import master

logger = logging.getLogger(__name__)

if __name__ == "__main__":
    import socket

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    connection = Tuple[str, int]
    connections: Dict[connection, Generator[Optional[Union[master.SVMessage, game.SVMessage]], bytes, None]] = {}
    count_inforesponse = 0

    q = master.CLGetServersExt(game="Xonotic", protocol=3)
    conn = (socket.gethostbyname("dpmaster.deathmask.net"), 27950)
    sock.sendto(q.encode(), conn)
    connections[conn] = master.sv_parse()
    while True:
        logger.debug("wait")
        data, addr = sock.recvfrom(1400)
        logger.debug(f"recv({addr}): {data}")
        msg = connections[addr].send(data)
        if msg:
            logger.info(f"recv({addr}): {msg}")
            if isinstance(msg, master.SVGetServersExtResponse):
                logger.info(f"servers: {len(msg.servers)}")
                for srv in msg.servers:
                    try:
                        q_info = game.CLGetInfo()
                        conn = (str(srv.addr), srv.port)
                        sock.sendto(q_info.encode(), conn)
                        connections[conn] = game.sv_parse()
                    except socket.gaierror:
                        pass
            if isinstance(msg, game.SVGetInfoResponse):
                count_inforesponse += 1
                logger.info(f"status-{count_inforesponse}: {msg}")
