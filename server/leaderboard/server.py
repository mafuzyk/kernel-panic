#!/usr/bin/env python3
"""Placar semanal do KERNEL PANIC, auto-hospedado.

O jogo é single-player e o save é base64 editável, então uma pontuação enviada
não vale nada por si. Este serviço não acredita em ninguém: ele guarda a
ENTRADA da run e re-simula a partida com o próprio jogo, headless, para
descobrir a pontuação. O que o cliente afirma é ignorado.

Só a biblioteca padrão. Nada para instalar, nada para atualizar, nada que
quebre numa máquina de casa enquanto ninguém está olhando.

Escuta em 127.0.0.1 de propósito. O acesso de fora é responsabilidade de um
túnel (Cloudflare Tunnel, Tailscale Funnel), que termina o TLS e nunca revela o
endereço residencial de quem hospeda. Não publique esta porta direto.
"""

from __future__ import annotations

import json
import os
import queue
import re
import sqlite3
import subprocess
import sys
import tempfile
import threading
import time
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HOST = os.environ.get("KP_BOARD_HOST", "127.0.0.1")
PORT = int(os.environ.get("KP_BOARD_PORT", "8710"))
PROJECT = Path(os.environ.get("KP_PROJECT", Path(__file__).resolve().parents[2]))
GODOT = os.environ.get("KP_GODOT", "godot")
DB_PATH = Path(os.environ.get("KP_BOARD_DB", Path(__file__).resolve().parent / "board.sqlite3"))

# Uma run de cinco minutos dá ~90 KB de entrada; 1 MiB deixa folga larga e ainda
# recusa qualquer coisa que só queira ocupar memória.
MAX_BODY = 1024 * 1024
# Re-simular custa um processo inteiro do jogo. A fila é curta porque CPU é o
# recurso escasso aqui, e uma fila longa só esconde a sobrecarga.
QUEUE_LIMIT = 32
VERIFY_TIMEOUT = 300
# Uma run precisa durar alguma coisa, e não pode durar para sempre.
MIN_FRAMES = 60
MAX_FRAMES = 60 * 60 * 90
BYTES_PER_FRAME = 5
NAME_RE = re.compile(r"^[A-Za-z0-9 _.\-]{1,24}$")

# ── limites de envio ──────────────────────────────────────────────────
#
# Atrás de um túnel — que é o jeito recomendado de expor isto — TODA requisição
# chega de 127.0.0.1. Um limite só por endereço virava um balde global: o sexto
# envio de qualquer pessoa em dez minutos levava 429.
#
# São dois limites, então. O por NOME é o de jogadora, que é a única identidade
# que existe aqui. O por endereço fica largo e serve de teto de CPU para o
# serviço inteiro.
RATE_WINDOW = 600
RATE_LIMIT_NAME = 5
RATE_LIMIT_TOTAL = 40
# O túnel põe o endereço real em `X-Forwarded-For`. Confiar nesse cabeçalho só
# faz sentido quando quem fala com o serviço é o túnel; ligado sem isso,
# qualquer pessoa forja o próprio limite.
TRUST_FORWARDED = os.environ.get("KP_BOARD_TRUST_FORWARDED", "") == "1"


def week_number(now: float | None = None) -> int:
    """A mesma conta do jogo (`Game.week_number`), para os dois concordarem."""
    days = int((now if now is not None else time.time()) / 86400.0)
    return int((days + 3) / 7.0)


class Database:
    """SQLite com uma trava. Um só escritor, e as leituras são minúsculas."""

    def __init__(self, path: Path) -> None:
        self._lock = threading.Lock()
        self._conn = sqlite3.connect(path, check_same_thread=False)
        self._conn.execute("PRAGMA journal_mode=WAL")
        self._conn.execute(
            """CREATE TABLE IF NOT EXISTS scores (
                   id INTEGER PRIMARY KEY AUTOINCREMENT,
                   week INTEGER NOT NULL,
                   name TEXT NOT NULL,
                   score INTEGER NOT NULL,
                   frames INTEGER NOT NULL,
                   seed INTEGER NOT NULL,
                   created REAL NOT NULL)"""
        )
        self._conn.execute(
            """CREATE TABLE IF NOT EXISTS submissions (
                   id TEXT PRIMARY KEY,
                   week INTEGER NOT NULL,
                   name TEXT NOT NULL,
                   state TEXT NOT NULL,
                   detail TEXT NOT NULL,
                   score INTEGER,
                   created REAL NOT NULL)"""
        )
        self._conn.execute("CREATE INDEX IF NOT EXISTS scores_week ON scores(week, score DESC)")
        self._conn.commit()

    def submission_open(self, sub_id: str, week: int, name: str) -> None:
        with self._lock:
            self._conn.execute(
                "INSERT INTO submissions (id, week, name, state, detail, score, created)"
                " VALUES (?, ?, ?, 'queued', '', NULL, ?)",
                (sub_id, week, name, time.time()),
            )
            self._conn.commit()

    def submission_close(self, sub_id: str, state: str, detail: str, score: int | None) -> None:
        with self._lock:
            self._conn.execute(
                "UPDATE submissions SET state = ?, detail = ?, score = ? WHERE id = ?",
                (state, detail, score, sub_id),
            )
            self._conn.commit()

    def submission(self, sub_id: str) -> dict | None:
        with self._lock:
            row = self._conn.execute(
                "SELECT id, week, name, state, detail, score FROM submissions WHERE id = ?",
                (sub_id,),
            ).fetchone()
        if row is None:
            return None
        return {"id": row[0], "week": row[1], "name": row[2], "state": row[3], "detail": row[4], "score": row[5]}

    def record_score(self, week: int, name: str, score: int, frames: int, seed: int) -> None:
        """Uma linha por nome por semana, e só melhora."""
        with self._lock:
            row = self._conn.execute(
                "SELECT id, score FROM scores WHERE week = ? AND name = ?", (week, name)
            ).fetchone()
            if row is None:
                self._conn.execute(
                    "INSERT INTO scores (week, name, score, frames, seed, created)"
                    " VALUES (?, ?, ?, ?, ?, ?)",
                    (week, name, score, frames, seed, time.time()),
                )
            elif score > int(row[1]):
                self._conn.execute(
                    "UPDATE scores SET score = ?, frames = ?, seed = ?, created = ? WHERE id = ?",
                    (score, frames, seed, time.time(), row[0]),
                )
            self._conn.commit()

    def board(self, week: int, limit: int) -> list[dict]:
        with self._lock:
            rows = self._conn.execute(
                "SELECT name, score, frames FROM scores WHERE week = ?"
                " ORDER BY score DESC, frames ASC, created ASC LIMIT ?",
                (week, limit),
            ).fetchall()
        return [
            {"rank": i + 1, "name": r[0], "score": int(r[1]), "frames": int(r[2])}
            for i, r in enumerate(rows)
        ]


class Verifier:
    """Re-simula um pacote com o próprio jogo e devolve o que a simulação deu."""

    def __init__(self, db: Database) -> None:
        self.db = db
        self.queue: queue.Queue = queue.Queue(maxsize=QUEUE_LIMIT)
        self._worker = threading.Thread(target=self._loop, daemon=True)

    def start(self) -> None:
        self._worker.start()

    def _loop(self) -> None:
        while True:
            sub_id, week, name, packet = self.queue.get()
            try:
                self._verify(sub_id, week, name, packet)
            except Exception as exc:  # noqa: BLE001 - um envio ruim não derruba o serviço
                self.db.submission_close(sub_id, "error", f"{type(exc).__name__}", None)
            finally:
                self.queue.task_done()

    def _verify(self, sub_id: str, week: int, name: str, packet: dict) -> None:
        with tempfile.TemporaryDirectory(prefix="kp-verify-") as workdir:
            work = Path(workdir)
            packet_path = work / "run.json"
            packet_path.write_text(json.dumps(packet))
            # Ambiente mínimo e descartável: o processo não enxerga o save de
            # ninguém, não escreve em HOME e não herda nada da sessão.
            #
            # O isolamento vem inteiro de HOME e das XDG_* apontando para este
            # diretório temporário. Havia um `KP_CLEAN_SAVE=1` aqui que o jogo
            # não lê — só o script da sessão virtual lê — e mantê-lo sugeria uma
            # segunda camada de proteção que nunca existiu.
            env = {
                "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
                "HOME": str(work),
                "XDG_DATA_HOME": str(work / "data"),
                "XDG_CONFIG_HOME": str(work / "config"),
                "XDG_CACHE_HOME": str(work / "cache"),
                "KP_WEEK": str(week),
                "KP_VERIFY_IN": str(packet_path),
            }
            try:
                done = subprocess.run(
                    [GODOT, "--headless", "--path", str(PROJECT)],
                    env=env, capture_output=True, text=True, timeout=VERIFY_TIMEOUT,
                )
            except subprocess.TimeoutExpired:
                self.db.submission_close(sub_id, "rejected", "verification timed out", None)
                return
            out = done.stdout
            if "REPLAY_MATCH yes" not in out:
                reason = "replay did not reproduce the recorded run"
                for line in out.splitlines():
                    if line.startswith("REPLAY_FAIL"):
                        reason = line.strip()
                        break
                self.db.submission_close(sub_id, "rejected", reason, None)
                return
            score = _tagged_int(out, "REPLAY_SCORE ")
            seed = _tagged_int(out, "REPLAY_SEED ")
            if score is None or seed is None:
                self.db.submission_close(sub_id, "error", "verifier produced no score", None)
                return
            frames = int(packet.get("frames", 0))
            self.db.record_score(week, name, score, frames, seed)
            self.db.submission_close(sub_id, "accepted", "verified by re-simulation", score)


def _tagged_int(text: str, tag: str) -> int | None:
    for line in text.splitlines():
        if line.startswith(tag):
            try:
                return int(line[len(tag):].strip())
            except ValueError:
                return None
    return None


class RateLimiter:
    """Janelas deslizantes independentes, uma por chave."""

    def __init__(self) -> None:
        self._hits: dict[str, list[float]] = {}
        self._lock = threading.Lock()

    def allow(self, key: str, limit: int) -> bool:
        now = time.time()
        with self._lock:
            hits = [t for t in self._hits.get(key, []) if now - t < RATE_WINDOW]
            if len(hits) >= limit:
                self._hits[key] = hits
                return False
            hits.append(now)
            self._hits[key] = hits
            return True

    def rollback(self, key: str) -> None:
        """Devolve a vaga quando o envio não chegou a ser enfileirado."""
        with self._lock:
            hits = self._hits.get(key, [])
            if hits:
                hits.pop()


def validate_packet(packet: dict) -> tuple[bool, str, int]:
    """Peneira barata, ANTES de gastar um processo do jogo re-simulando."""
    if not isinstance(packet, dict):
        return False, "packet is not an object", 0
    try:
        week = int(packet["week"])
        frames = int(packet["frames"])
        blob = packet["input"]
    except (KeyError, TypeError, ValueError):
        return False, "packet is missing week, frames or input", 0
    if not isinstance(blob, str):
        return False, "input is not a string", 0
    current = week_number()
    # A semana passada ainda é aceita: quem joga no domingo à noite envia depois
    # da virada. Mais velho que isso, ou no futuro, não.
    if week not in (current, current - 1):
        return False, f"week {week} is not open (current {current})", 0
    if not MIN_FRAMES <= frames <= MAX_FRAMES:
        return False, f"frame count {frames} is out of range", 0
    # O tamanho é conferido contra `input_frames`, que descreve o BUFFER. O
    # campo `frames` conta outra coisa — os quadros que a run jogou — e usar um
    # pelo outro recusava pacotes honestos.
    try:
        input_frames = int(packet["input_frames"])
    except (KeyError, TypeError, ValueError):
        return False, "packet is missing input_frames", 0
    if not MIN_FRAMES <= input_frames <= MAX_FRAMES:
        return False, f"input frame count {input_frames} is out of range", 0
    expected = input_frames * BYTES_PER_FRAME
    # base64: 4 caracteres a cada 3 bytes, com folga para o preenchimento.
    if not expected <= len(blob) * 3 / 4 <= expected + 16:
        return False, "input length does not match the frame count", 0
    picks = packet.get("picks", [])
    if not isinstance(picks, list) or len(picks) > 64:
        return False, "patch picks are malformed", 0
    return True, "", week


class Handler(BaseHTTPRequestHandler):
    server_version = "kernel-panic-board/1"
    db: Database
    verifier: Verifier
    limiter: RateLimiter

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("[board] %s\n" % (fmt % args))

    def _origin(self) -> str:
        """Quem está falando, para o teto de CPU do serviço.

        Atrás de um túnel o endereço do socket é sempre 127.0.0.1, e o endereço
        real vem em `X-Forwarded-For`. Ele só é lido quando `TRUST_FORWARDED`
        diz que quem fala com este serviço é o túnel — caso contrário qualquer
        pessoa escolheria o próprio balde.
        """
        if TRUST_FORWARDED:
            forwarded = self.headers.get("X-Forwarded-For", "")
            if forwarded:
                return forwarded.split(",")[0].strip()[:64]
        return self.client_address[0]

    def _json(self, status: HTTPStatus, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802 - assinatura da stdlib
        path, _, raw_query = self.path.partition("?")
        query = {}
        for part in raw_query.split("&"):
            if "=" in part:
                key, _, value = part.partition("=")
                query[key] = value
        if path == "/v1/health":
            self._json(HTTPStatus.OK, {"ok": True, "week": week_number()})
            return
        if path == "/v1/board":
            try:
                week = int(query.get("week", week_number()))
                limit = max(1, min(int(query.get("limit", 20)), 100))
            except ValueError:
                self._json(HTTPStatus.BAD_REQUEST, {"error": "week and limit must be integers"})
                return
            self._json(HTTPStatus.OK, {"week": week, "entries": self.db.board(week, limit)})
            return
        if path.startswith("/v1/submission/"):
            found = self.db.submission(path.rsplit("/", 1)[-1])
            if found is None:
                self._json(HTTPStatus.NOT_FOUND, {"error": "no such submission"})
                return
            self._json(HTTPStatus.OK, found)
            return
        self._json(HTTPStatus.NOT_FOUND, {"error": "no such route"})

    def do_POST(self) -> None:  # noqa: N802 - assinatura da stdlib
        if self.path != "/v1/submit":
            self._json(HTTPStatus.NOT_FOUND, {"error": "no such route"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self._json(HTTPStatus.BAD_REQUEST, {"error": "bad content length"})
            return
        if length <= 0 or length > MAX_BODY:
            self._json(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, {"error": "body too large"})
            return
        try:
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            self._json(HTTPStatus.BAD_REQUEST, {"error": "body is not valid json"})
            return
        name = str(payload.get("name", "")).strip()
        if not NAME_RE.match(name):
            self._json(HTTPStatus.BAD_REQUEST, {"error": "name must be 1-24 plain characters"})
            return
        packet = payload.get("run")
        ok, why, week = validate_packet(packet)
        if not ok:
            self._json(HTTPStatus.BAD_REQUEST, {"error": why})
            return
        # A janela conta o que chega a CUSTAR alguma coisa. Recusar um corpo
        # malformado é um regex; re-simular uma run é um processo do jogo
        # inteiro. Contar as recusas deixava um envio honesto sem vaga porque
        # alguém mandou lixo antes.
        if not self.limiter.allow("name:%s" % name.lower(), RATE_LIMIT_NAME):
            self._json(HTTPStatus.TOO_MANY_REQUESTS, {"error": "too many submissions for that name, try later"})
            return
        origin = self._origin()
        if not self.limiter.allow("addr:%s" % origin, RATE_LIMIT_TOTAL):
            self.limiter.rollback("name:%s" % name.lower())
            self._json(HTTPStatus.TOO_MANY_REQUESTS, {"error": "the board is saturated, try later"})
            return
        sub_id = os.urandom(12).hex()
        self.db.submission_open(sub_id, week, name)
        try:
            self.verifier.queue.put_nowait((sub_id, week, name, packet))
        except queue.Full:
            self.db.submission_close(sub_id, "rejected", "verification queue is full", None)
            self._json(HTTPStatus.SERVICE_UNAVAILABLE, {"error": "busy, try later"})
            return
        self._json(HTTPStatus.ACCEPTED, {"id": sub_id, "state": "queued"})


def main() -> int:
    db = Database(DB_PATH)
    verifier = Verifier(db)
    verifier.start()
    Handler.db = db
    Handler.verifier = verifier
    Handler.limiter = RateLimiter()
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    sys.stderr.write(f"[board] listening on {HOST}:{PORT} project={PROJECT} week={week_number()}\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
