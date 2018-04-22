#!/usr/bin/env python3

import asyncio
import http.server
import io
import json
import os
import shutil
import socketserver
from http import HTTPStatus
from http.client import HTTPMessage
from threading import Thread
from typing import Dict, Awaitable, NoReturn, cast, Any, Optional
from urllib.request import urlopen


class Config:
    __slots__ = \
        "port", \
        "upstream", \
        "dlcache"

    def __init__(self) -> None:
        self.port = int(os.getenv("PORT", "8000"))
        # upstream file url, should end in slash
        self.upstream = os.getenv("UPSTREAM", "http://beta.xonotic.org/autobuild-bsp/")
        self.dlcache = os.getenv("DLCACHE", os.path.join(os.getcwd(), "dlcache"))


class App:
    __slots__ = \
        "config", \
        "_files"

    def __init__(self, config: Config) -> None:
        self.config = config
        os.makedirs(config.dlcache, exist_ok=True)
        self._files: Dict[str, Awaitable[None]] = {}

    async def file_get(self, name: str) -> None:
        url = self.config.upstream + name
        f = self._files.get(url)
        if not f:
            print("cache miss")
            f = asyncio.get_event_loop().create_future()
            self._files[url] = f
            await self._fetch(url, name)
            f.set_result(None)
        else:
            print("using existing")
            await f

    async def file_wait(self, url: str) -> None:
        await self._files[url]

    async def _fetch(self, url: str, out: str) -> None:
        out = os.path.join(self.config.dlcache, out)
        res = cast(Any, urlopen(url))
        with open(out, "wb") as f:
            msg: HTTPMessage = res.info()
            file_size = int(str(msg.get("Content-length")))
            print(f"downloading {file_size} bytes...")
            progress = 0
            block = 16 * 1024
            while True:
                buf: bytes = res.read(block)
                if not buf:
                    break
                progress += len(buf)
                print(f"downloaded {progress}/{file_size} bytes")
                f.write(buf)
                await asyncio.sleep(0)


def main() -> None:
    config = Config()
    app = App(config)

    def router() -> Router:
        return RouterCombinator(
            fetch=Fetch(),
        )

    class Fetch(Router):
        async def __call__(self, path: str, req: Request) -> Response:
            await app.file_get(path)
            return None

    loop = asyncio.get_event_loop()
    start_server(config, loop, router())
    try:
        loop.run_forever()
    except KeyboardInterrupt:
        pass
    finally:
        loop.close()


class Request:
    pass


Response = Optional[dict]


class Router:
    async def __call__(self, path: str, req: Request) -> Response:
        pass


class RouterCombinator(Router):
    __slots__ = "_routers"

    def __init__(self, **kwargs: Any) -> None:
        self._routers: Dict[str, Router] = kwargs

    async def __call__(self, path: str, req: Request) -> Response:
        while True:
            name, rest = path.split("/", 1)
            if name:
                break
            path = rest
        route = self._routers.get(name, None)
        if not route:
            return None
        return await route(rest, req)


def start_server(config: Config, loop: asyncio.AbstractEventLoop, router: Router) -> None:
    async def on_message(req: http.server.BaseHTTPRequestHandler) -> None:
        ret = await router(req.path, Request())
        if not ret:
            ret = {}
        req.send_response(HTTPStatus.OK)
        req.send_header("Content-Type", "application/json")
        s = json.dumps(ret, indent=2).encode("utf-8")
        req.send_header("Content-Length", str(len(s)))
        req.end_headers()
        f = io.BytesIO()
        f.write(s)
        f.seek(0)
        try:
            shutil.copyfileobj(f, req.wfile)
        finally:
            f.close()

    def serve(loop: asyncio.AbstractEventLoop) -> NoReturn:
        class ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
            pass

        class RequestHandler(http.server.BaseHTTPRequestHandler):
            def do_GET(self) -> None:
                asyncio.run_coroutine_threadsafe(on_message(self), loop).result()

        with ThreadingHTTPServer(("", config.port), RequestHandler) as httpd:
            print("serving at port", config.port)
            httpd.serve_forever()

        assert False, "Unreachable"

    server = Thread(target=serve, args=(loop,))
    server.daemon = True
    server.start()


if __name__ == "__main__":
    main()
