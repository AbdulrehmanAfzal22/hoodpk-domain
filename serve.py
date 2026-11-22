from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


class StorefrontHandler(SimpleHTTPRequestHandler):
    def send_head(self):
        requested_path = urlsplit(self.path).path
        local_path = Path(self.translate_path(requested_path))
        if not local_path.exists() and not Path(requested_path).suffix:
            self.path = "/index.html"
        return super().send_head()


if __name__ == "__main__":
    from functools import partial
    import argparse

    parser = argparse.ArgumentParser(description="Serve the storefront preview with SPA routing.")
    parser.add_argument("--port", type=int, default=4173)
    args = parser.parse_args()

    handler = partial(StorefrontHandler, directory="dist")
    server = ThreadingHTTPServer(("0.0.0.0", args.port), handler)
    print(f"Serving storefront at http://localhost:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
