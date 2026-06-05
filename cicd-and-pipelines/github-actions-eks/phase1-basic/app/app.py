from flask import Flask, jsonify
import socket
import os

app = Flask(__name__)

VERSION = os.getenv("APP_VERSION", "v1")


@app.route("/")
def hello():
    return jsonify({
        "message": "Hello from EKS",
        "hostname": socket.gethostname(),
        "version": VERSION,
    })


@app.route("/health")
def health():
    return jsonify({"status": "alive"})
