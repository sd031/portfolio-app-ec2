-- Initialize database schema and sample data

USE appdb;

-- Create projects table
CREATE TABLE IF NOT EXISTS projects (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    technologies VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create skills table
CREATE TABLE IF NOT EXISTS skills (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create contacts table
CREATE TABLE IF NOT EXISTS contacts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample projects
INSERT INTO projects (name, description, technologies) VALUES
('E-Commerce Platform', 'Full-stack e-commerce solution with payment integration', 'React, Node.js, MongoDB, Stripe'),
('Cloud Infrastructure Automation', 'Automated AWS infrastructure deployment using Terraform', 'Terraform, AWS, Python, CI/CD'),
('Real-time Chat Application', 'Scalable chat app with WebSocket support', 'Socket.io, Express, Redis, React'),
('Machine Learning Pipeline', 'End-to-end ML pipeline for predictive analytics', 'Python, TensorFlow, Docker, Kubernetes'),
('3-Tier Web Application', 'Production-ready web app with Docker and AWS deployment', 'Flask, MySQL, Docker, Terraform');

-- Insert sample skills
INSERT INTO skills (name, category) VALUES
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
('Redis', 'Database'),
('Node.js', 'Backend'),
('TypeScript', 'Frontend');
