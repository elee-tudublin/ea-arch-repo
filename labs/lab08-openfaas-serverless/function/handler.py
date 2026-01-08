import os
from flask import Flask, request, jsonify

app = Flask(__name__)

BANNED = [w.strip().lower() for w in os.getenv("BANNED_WORDS", "spam,hate,illegal").split(",")]

@app.post('/')
def handle():
    data = request.get_json(silent=True) or {}
    text = str(data.get('text', ''))
    lowered = text.lower()
    for w in BANNED:
        if w and w in lowered:
            return jsonify({'decision': 'block', 'reason_code': 'keyword_match', 'confidence': 0.9})
    return jsonify({'decision': 'allow', 'reason_code': 'clean', 'confidence': 0.6})
