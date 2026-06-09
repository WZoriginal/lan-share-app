import json
import re
from datetime import datetime
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import quote, unquote, urlparse


HOST = "0.0.0.0"
PORT = int(__import__("os").environ.get("LAN_SHARE_PORT", "8000"))
ROOT = Path(__file__).resolve().parent
FILES_DIR = ROOT / "files"
LOG_DIR = ROOT / "logs"
LOG_FILE = LOG_DIR / "server.log"
MAX_UPLOAD_SIZE = 512 * 1024 * 1024


def ensure_runtime_dirs():
    FILES_DIR.mkdir(exist_ok=True)
    LOG_DIR.mkdir(exist_ok=True)


def write_log(message):
    ensure_runtime_dirs()
    LOG_FILE.open("a", encoding="utf-8").write(message + "\n")


def human_size(size):
    units = ["B", "KB", "MB", "GB"]
    value = float(size)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            return f"{int(value)} {unit}" if unit == "B" else f"{value:.1f} {unit}"
        value /= 1024


def file_record(path):
    relative = path.relative_to(ROOT).as_posix()
    suffix = path.suffix[1:].upper() if path.suffix else "FILE"
    stat = path.stat()
    return {
        "name": path.name,
        "type": suffix,
        "bytes": stat.st_size,
        "size": human_size(stat.st_size),
        "updated": datetime.fromtimestamp(stat.st_mtime).strftime("%Y-%m-%d %H:%M"),
        "path": relative,
        "url": quote(relative, safe="/"),
    }


def list_shared_files():
    ensure_runtime_dirs()
    files = [path for path in FILES_DIR.iterdir() if path.is_file() and path.name != ".gitkeep"]
    files.sort(key=lambda item: item.stat().st_mtime, reverse=True)
    return [file_record(path) for path in files]


def resolve_shared_file(path_value):
    ensure_runtime_dirs()
    cleaned = unquote(str(path_value or "")).replace("\\", "/").lstrip("/")
    candidate = ROOT / cleaned if cleaned.startswith("files/") else FILES_DIR / cleaned
    target = candidate.resolve()
    try:
        target.relative_to(FILES_DIR.resolve())
    except ValueError:
        return None
    return target if target.is_file() and target.name != ".gitkeep" else None


def delete_shared_file(path_value):
    target = resolve_shared_file(path_value)
    if target is None:
        return None
    deleted = file_record(target)
    target.unlink()
    return deleted


def safe_filename(filename):
    name = unquote(filename).replace("\\", "/").split("/")[-1].strip()
    name = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", name).rstrip(" .")
    return name or "upload"


def unique_target(filename):
    ensure_runtime_dirs()
    path = FILES_DIR / safe_filename(filename)
    if not path.exists():
        return path

    stem = path.stem or "upload"
    suffix = path.suffix
    index = 1
    while True:
        candidate = FILES_DIR / f"{stem} ({index}){suffix}"
        if not candidate.exists():
            return candidate
        index += 1


def extract_filename(disposition):
    star = re.search(r"filename\*=([^;]+)", disposition, re.IGNORECASE)
    if star:
        value = star.group(1).strip().strip('"')
        return value.split("''", 1)[-1] if "''" in value else value

    quoted = re.search(r'filename="([^"]*)"', disposition, re.IGNORECASE)
    if quoted:
        return quoted.group(1)

    plain = re.search(r"filename=([^;]+)", disposition, re.IGNORECASE)
    return plain.group(1).strip() if plain else ""


def parse_multipart_files(body, boundary):
    delimiter = b"--" + boundary.encode("utf-8")
    saved = []

    for part in body.split(delimiter):
        if not part or part in (b"--", b"--\r\n", b"\r\n"):
            continue

        if part.startswith(b"\r\n"):
            part = part[2:]
        if part.endswith(b"--"):
            part = part[:-2]
        if part.endswith(b"\r\n"):
            part = part[:-2]
        if b"\r\n\r\n" not in part:
            continue

        raw_headers, content = part.split(b"\r\n\r\n", 1)
        headers = {}
        for line in raw_headers.decode("utf-8", "replace").split("\r\n"):
            if ":" in line:
                key, value = line.split(":", 1)
                headers[key.lower().strip()] = value.strip()

        filename = extract_filename(headers.get("content-disposition", ""))
        if not filename:
            continue

        target = unique_target(filename)
        target.write_bytes(content)
        saved.append(file_record(target))

    return saved


class LanShareHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def log_message(self, fmt, *args):
        write_log("%s - %s" % (self.address_string(), fmt % args))

    def send_json(self, status, payload):
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if urlparse(self.path).path == "/api/files":
            self.send_json(200, {"files": list_shared_files()})
            return
        super().do_GET()

    def do_POST(self):
        parsed = urlparse(self.path)

        if parsed.path == "/api/delete":
            length = int(self.headers.get("Content-Length", "0"))
            try:
                payload = json.loads(self.rfile.read(length).decode("utf-8"))
            except Exception:
                self.send_json(400, {"error": "删除请求格式无效。"})
                return

            deleted = delete_shared_file(payload.get("path"))
            if deleted is None:
                self.send_json(404, {"error": "文件不存在或不在共享目录中。"})
                return

            self.send_json(200, {"deleted": deleted, "files": list_shared_files()})
            return

        if parsed.path != "/api/upload":
            self.send_error(404, "Not found")
            return

        content_type = self.headers.get("Content-Type", "")
        match = re.search(r'boundary=(?:"([^"]+)"|([^;]+))', content_type)
        if not match:
            self.send_json(400, {"error": "缺少上传边界。"})
            return

        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0:
            self.send_json(400, {"error": "没有收到文件。"})
            return
        if length > MAX_UPLOAD_SIZE:
            self.send_json(413, {"error": "单次上传不能超过 512 MB。"})
            return

        saved = parse_multipart_files(self.rfile.read(length), match.group(1) or match.group(2))
        if not saved:
            self.send_json(400, {"error": "没有可保存的文件。"})
            return

        self.send_json(200, {"uploaded": saved, "files": list_shared_files()})


def main():
    ensure_runtime_dirs()
    server = ThreadingHTTPServer((HOST, PORT), LanShareHandler)
    write_log(f"Serving {ROOT} at http://{HOST}:{PORT}/")
    print(f"LAN Share is running at http://127.0.0.1:{PORT}/")
    server.serve_forever()


if __name__ == "__main__":
    main()
