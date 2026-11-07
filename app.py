"""Simple Flask backend used for the Terraform DevOps assignment."""
import os
import socket
from datetime import datetime, timezone

from flask import Flask, jsonify

app = Flask(__name__)

STUDENT_NAME = os.getenv("STUDENT_NAME", "Snehal")


def _now():
    return datetime.now(timezone.utc).isoformat()


@app.get("/")
def index():
    return jsonify(
        service="flask-backend",
        status="ok",
        message="Flask backend is running",
        endpoints=["/api/health", "/api/message", "/api/info"],
    )


@app.get("/api/health")
def health():
    return jsonify(status="healthy", service="flask-backend", time=_now())


@app.get("/api/message")
def message():
    return jsonify(
        message="Hello from the Flask backend, deployed with Terraform!",
        author=STUDENT_NAME,
        host=socket.gethostname(),
        time=_now(),
    )


@app.get("/api/info")
def info():
    return jsonify(
        service="flask-backend",
        host=socket.gethostname(),
        port=int(os.getenv("PORT", "5000")),
        time=_now(),
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "5000")))
