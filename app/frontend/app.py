from flask import Flask, render_template, jsonify, request
import requests
import os
import logging

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Backend API URL (will be set via environment variable)
BACKEND_URL = os.environ.get('BACKEND_URL', 'http://localhost:5001')

@app.route('/')
def index():
    """Main portfolio page"""
    return render_template('index.html')

@app.route('/health')
def health():
    """Health check endpoint for ALB"""
    return jsonify({'status': 'healthy', 'service': 'frontend'}), 200

@app.route('/api/projects')
def get_projects():
    """Fetch projects from backend API"""
    try:
        response = requests.get(f'{BACKEND_URL}/api/projects', timeout=5)
        return jsonify(response.json()), response.status_code
    except requests.exceptions.RequestException as e:
        logger.error(f"Error connecting to backend: {e}")
        return jsonify({'error': 'Backend service unavailable'}), 503

@app.route('/api/skills')
def get_skills():
    """Fetch skills from backend API"""
    try:
        response = requests.get(f'{BACKEND_URL}/api/skills', timeout=5)
        return jsonify(response.json()), response.status_code
    except requests.exceptions.RequestException as e:
        logger.error(f"Error connecting to backend: {e}")
        return jsonify({'error': 'Backend service unavailable'}), 503

@app.route('/api/contact', methods=['POST'])
def submit_contact():
    """Submit contact form to backend API"""
    try:
        data = request.get_json()
        response = requests.post(f'{BACKEND_URL}/api/contact', json=data, timeout=5)
        return jsonify(response.json()), response.status_code
    except requests.exceptions.RequestException as e:
        logger.error(f"Error connecting to backend: {e}")
        return jsonify({'error': 'Backend service unavailable'}), 503

@app.route('/api/stats')
def get_stats():
    """Fetch statistics from backend API"""
    try:
        response = requests.get(f'{BACKEND_URL}/api/stats', timeout=5)
        return jsonify(response.json()), response.status_code
    except requests.exceptions.RequestException as e:
        logger.error(f"Error connecting to backend: {e}")
        return jsonify({'error': 'Backend service unavailable'}), 503

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
