#!/usr/bin/env python3

import asyncio
import http.server
import io
import json
import os
import shutil
import socketserver
from html.parser import HTMLParser
from http import HTTPStatus
from http.client import HTTPMessage
from threading import Thread
from typing import Dict, Awaitable, NoReturn, cast, Any, Optional, List, Tuple, AsyncGenerator
from urllib.parse import unquote
from urllib.request import urlopen

UTF_8 = "utf-8"
IO_BLOCK = 16 * 1024


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
        self._files: Dict[str, Awaitable[bool]] = {}

    async def file_get(self, name: str) -> None:
        url = self.config.upstream + name
        future = self._files.get(url)
        if not future:
            print("cache miss")
            future = asyncio.get_event_loop().create_future()
            self._files[url] = future
            out = os.path.join(self.config.dlcache, name)
            with open(out, "wb") as f:
                async for buf in fetch(url):
                    f.write(buf)
            future.set_result(True)
        else:
            print("using existing")
            await future

    async def file_wait(self, url: str) -> None:
        await self._files[url]

    async def ls(self) -> List[str]:
        class Parser(HTMLParser):
            __slots__ = "paks"

            def __init__(self) -> None:
                super().__init__()
                self.paks: List[str] = []

            def handle_starttag(self, tag: str, attrs: List[Tuple[str, str]]) -> None:
                if tag == "a":
                    file: Optional[str] = next((unquote(v) for (k, v) in attrs if k == "href"), None)
                    if file and file.endswith(".pk3"):
                        self.paks.append(file)

        parser = Parser()
        arr = bytearray()
        async for buf in fetch(self.config.upstream):
            arr.extend(buf)
        buf = arr
        parser.feed(buf.decode(UTF_8))
        return parser.paks


def main() -> None:
    config = Config()
    app = App(config)

    def router() -> Router:
        return RouterCombinator(
            fetch=FileFetch(),
            ls=FileList()
        )

    class FileFetch(Router):
        async def __call__(self, path: str, req: Request) -> Response:
            await app.file_get(path)
            return {
                "ready": True,
            }

    class FileList(Router):
        async def __call__(self, path: str, req: Request) -> Response:
            return {
                "list": await app.ls(),
            }

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
            args: List[str] = path.split("/", 1)
            name = args[0]
            rest = args[1] if len(args) > 1 else None
            if name:
                break
            if not rest:
                return None
            path = rest
        route = self._routers.get(name, None)
        if not route:
            return None
        return await route(rest or "", req)


async def fetch(url: str) -> AsyncGenerator[bytes, None]:
    res = cast(Any, urlopen(url))
    msg: HTTPMessage = res.info()
    print("msg", msg)
    length = msg.get("Content-length")
    file_size = int(str(length)) if length else None
    print(f"downloading {file_size or '???'} bytes...")
    progress = 0
    while True:
        buf: bytes = res.read(IO_BLOCK)
        if not buf:
            break
        progress += len(buf)
        print(f"downloaded {progress}/{file_size or '???'} bytes")
        yield buf
        await asyncio.sleep(0)


def start_server(config: Config, loop: asyncio.AbstractEventLoop, router: Router) -> None:
    async def on_message(req: http.server.BaseHTTPRequestHandler) -> None:
        ret = await router(req.path, Request())
        if not ret:
            ret = {}
        req.send_response(HTTPStatus.OK)
        req.send_header("Content-Type", "application/json")
        s = json.dumps(ret, indent=2).encode(UTF_8)
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
