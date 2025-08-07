from flask import Flask, render_template, request, make_response, g
from redis import Redis
import os
import socket
import random
import json
import logging

option_a = os.getenv('OPTION_A', "Cats")
option_b = os.getenv('OPTION_B', "Dogs")
hostname = socket.gethostname()

app = Flask(__name__)

# Enhanced logging for development
logging.basicConfig(level=logging.INFO)
gunicorn_error_logger = logging.getLogger('gunicorn.error')
app.logger.handlers.extend(gunicorn_error_logger.handlers)
app.logger.setLevel(logging.INFO)

def get_redis():
    if not hasattr(g, 'redis'):
        redis_host = os.getenv('REDIS_HOST', 'redis')
        app.logger.info(f'Connecting to Redis at {redis_host}')
        g.redis = Redis(host=redis_host, db=0, socket_timeout=5)
    return g.redis

@app.route("/", methods=['POST','GET'])
def hello():
    voter_id = request.cookies.get('voter_id')
    if not voter_id:
        voter_id = hex(random.getrandbits(64))[2:-1]

    vote = None

    if request.method == 'POST':
        redis = get_redis()
        vote = request.form['vote']
        app.logger.info('Received vote for %s from %s', vote, voter_id)
        data = json.dumps({'voter_id': voter_id, 'vote': vote})
        redis.rpush('votes', data)

    resp = make_response(render_template(
        'index.html',
        option_a=option_a,
        option_b=option_b,
        hostname=hostname,
        vote=vote,
    ))
    resp.set_cookie('voter_id', voter_id)
    return resp

@app.route("/health")
def health():
    """Health check endpoint for development"""
    try:
        redis = get_redis()
        redis.ping()
        return {"status": "healthy", "redis": "connected", "hostname": hostname}
    except Exception as e:
        app.logger.error(f'Health check failed: {e}')
        return {"status": "unhealthy", "error": str(e)}, 503

if __name__ == "__main__":
    # Development server with hot reload
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_DEBUG', 'true').lower() == 'true'
    app.logger.info(f'Starting development server on port {port}, debug={debug}')
    app.run(host='0.0.0.0', port=port, debug=debug, threaded=True)
