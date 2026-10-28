"""Read-only localhost JSON API for the local food catalog."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import sqlite3
from urllib.parse import parse_qs, unquote, urlsplit

import catalog


def make_handler(database):
    class FoodHandler(BaseHTTPRequestHandler):
        def do_GET(self):
            route = urlsplit(self.path)
            query = parse_qs(route.query)
            db = sqlite3.connect(Path(database).resolve().as_uri() + '?mode=ro', uri=True)
            db.row_factory = sqlite3.Row
            try:
                if route.path == '/health':
                    result = dict(status='ok', schema_version=db.execute('PRAGMA user_version').fetchone()[0],
                                  foods=db.execute('SELECT COUNT(*) FROM commercial_foods').fetchone()[0])
                elif route.path == '/foods':
                    result = dict(foods=catalog.search(db, query.get('q', [''])[0],
                                                      int(query.get('limit', ['20'])[0])))
                elif route.path.startswith('/foods/'):
                    try:
                        result = catalog.detail(db, unquote(route.path[len('/foods/'):]))
                    except ValueError:
                        self.send_json(404, dict(error='Food not found'))
                        return
                else:
                    self.send_json(404, dict(error='Not found'))
                    return
                self.send_json(200, result)
            except ValueError as error:
                self.send_json(400, dict(error=str(error)))
            except sqlite3.Error:
                self.send_json(500, dict(error='Database query failed'))
            finally:
                db.close()

        def send_json(self, status, value):
            body = json.dumps(value, ensure_ascii=False, allow_nan=False).encode()
            self.send_response(status)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, format, *args):
            pass

    return FoodHandler


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--db', type=Path, default=catalog.ROOT / '.data/exports/KeepFitFoods.sqlite')
    parser.add_argument('--port', type=int, default=8767)
    args = parser.parse_args()
    if not args.db.is_file():
        parser.error('Database does not exist; run catalog.py export first')
    server = ThreadingHTTPServer(('127.0.0.1', args.port), make_handler(args.db))
    print('Food catalog: http://127.0.0.1:%d/foods?q=rice' % args.port, flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
