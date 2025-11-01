from flask import Flask, jsonify, request
from flask_cors import CORS
import mysql.connector
from mysql.connector import Error
import os
import logging
from datetime import datetime

app = Flask(__name__)
CORS(app)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Database configuration from environment variables
DB_CONFIG = {
    'host': os.environ.get('DB_HOST', 'localhost'),
    'database': os.environ.get('DB_NAME', 'appdb'),
    'user': os.environ.get('DB_USER', 'admin'),
    'password': os.environ.get('DB_PASSWORD', ''),
}

def get_db_connection():
    """Create and return a database connection"""
    try:
        connection = mysql.connector.connect(**DB_CONFIG)
        if connection.is_connected():
            return connection
    except Error as e:
        logger.error(f"Error connecting to MySQL: {e}")
        return None

def init_database():
    """Initialize database tables if they don't exist"""
    connection = get_db_connection()
    if not connection:
        logger.warning("Could not initialize database - connection failed")
        return
    
    try:
        cursor = connection.cursor()
        
        # Create projects table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS projects (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                description TEXT,
                technologies VARCHAR(255),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Create skills table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS skills (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(100) NOT NULL,
                category VARCHAR(100),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Create contacts table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS contacts (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                email VARCHAR(255) NOT NULL,
                message TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Insert sample data if tables are empty
        cursor.execute("SELECT COUNT(*) FROM projects")
        if cursor.fetchone()[0] == 0:
            sample_projects = [
                ('E-Commerce Platform', 'Full-stack e-commerce solution with payment integration', 'React, Node.js, MongoDB, Stripe'),
                ('Cloud Infrastructure Automation', 'Automated AWS infrastructure deployment using Terraform', 'Terraform, AWS, Python, CI/CD'),
                ('Real-time Chat Application', 'Scalable chat app with WebSocket support', 'Socket.io, Express, Redis, React'),
                ('Machine Learning Pipeline', 'End-to-end ML pipeline for predictive analytics', 'Python, TensorFlow, Docker, Kubernetes'),
            ]
            cursor.executemany(
                "INSERT INTO projects (name, description, technologies) VALUES (%s, %s, %s)",
                sample_projects
            )
        
        cursor.execute("SELECT COUNT(*) FROM skills")
        if cursor.fetchone()[0] == 0:
            sample_skills = [
                ('Python', 'Backend'),
                ('JavaScript', 'Frontend'),
                ('AWS', 'Cloud'),
                ('Terraform', 'IaC'),
                ('Docker', 'DevOps'),
                ('Kubernetes', 'DevOps'),
                ('React', 'Frontend'),
                ('Flask', 'Backend'),
                ('MySQL', 'Database'),
                ('MongoDB', 'Database'),
                ('Git', 'Version Control'),
                ('CI/CD', 'DevOps'),
            ]
            cursor.executemany(
                "INSERT INTO skills (name, category) VALUES (%s, %s)",
                sample_skills
            )
        
        connection.commit()
        logger.info("Database initialized successfully")
        
    except Error as e:
        logger.error(f"Error initializing database: {e}")
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

@app.route('/health')
def health():
    """Health check endpoint"""
    connection = get_db_connection()
    db_status = 'connected' if connection else 'disconnected'
    if connection:
        connection.close()
    
    return jsonify({
        'status': 'healthy',
        'service': 'backend',
        'database': db_status,
        'timestamp': datetime.now().isoformat()
    }), 200

@app.route('/api/projects', methods=['GET'])
def get_projects():
    """Get all projects from database"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'error': 'Database connection failed'}), 503
    
    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT id, name, description, technologies FROM projects")
        projects = cursor.fetchall()
        
        return jsonify({'projects': projects}), 200
        
    except Error as e:
        logger.error(f"Error fetching projects: {e}")
        return jsonify({'error': 'Failed to fetch projects'}), 500
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

@app.route('/api/skills', methods=['GET'])
def get_skills():
    """Get all skills from database"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'error': 'Database connection failed'}), 503
    
    try:
        cursor = connection.cursor()
        cursor.execute("SELECT name FROM skills ORDER BY category, name")
        skills = [row[0] for row in cursor.fetchall()]
        
        return jsonify({'skills': skills}), 200
        
    except Error as e:
        logger.error(f"Error fetching skills: {e}")
        return jsonify({'error': 'Failed to fetch skills'}), 500
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

@app.route('/api/contact', methods=['POST'])
def submit_contact():
    """Save contact form submission to database"""
    data = request.get_json()
    
    if not data or not all(k in data for k in ('name', 'email', 'message')):
        return jsonify({'error': 'Missing required fields'}), 400
    
    connection = get_db_connection()
    if not connection:
        return jsonify({'error': 'Database connection failed'}), 503
    
    try:
        cursor = connection.cursor()
        cursor.execute(
            "INSERT INTO contacts (name, email, message) VALUES (%s, %s, %s)",
            (data['name'], data['email'], data['message'])
        )
        connection.commit()
        
        logger.info(f"Contact form submitted by {data['email']}")
        return jsonify({'message': 'Contact form submitted successfully'}), 201
        
    except Error as e:
        logger.error(f"Error saving contact: {e}")
        return jsonify({'error': 'Failed to save contact'}), 500
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

@app.route('/api/stats', methods=['GET'])
def get_stats():
    """Get portfolio statistics"""
    connection = get_db_connection()
    if not connection:
        return jsonify({'error': 'Database connection failed'}), 503
    
    try:
        cursor = connection.cursor()
        
        cursor.execute("SELECT COUNT(*) FROM projects")
        projects_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM skills")
        skills_count = cursor.fetchone()[0]
        
        stats = {
            'projects_count': projects_count,
            'skills_count': skills_count,
            'experience_years': 5,
            'certifications': 3
        }
        
        return jsonify(stats), 200
        
    except Error as e:
        logger.error(f"Error fetching stats: {e}")
        return jsonify({'error': 'Failed to fetch statistics'}), 500
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()

if __name__ == '__main__':
    # Initialize database on startup
    init_database()
    
    # Run the application
    app.run(host='0.0.0.0', port=5001, debug=False)
