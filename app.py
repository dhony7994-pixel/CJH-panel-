import os
import sqlite3
import subprocess
from flask import Flask, render_template, request, redirect, url_for, session, jsonify
from werkzeug.security import generate_password_hash, check_password_hash

app = Flask(__name__)
app.secret_key = os.urandom(24)

DB_PATH = '/opt/cjh-panel/cjh_database.db'

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    cursor = conn.cursor()
    # Users table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            role TEXT DEFAULT 'user'
        )
    ''')
    # Bots table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS bots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            cmd TEXT NOT NULL,
            status TEXT DEFAULT 'stopped'
        )
    ''')
    # VPS table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS vps (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            ram INTEGER NOT NULL,
            vcpu INTEGER NOT NULL,
            status TEXT DEFAULT 'stopped'
        )
    ''')
    conn.commit()
    conn.close()

init_db()

@app.route('/')
def index():
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('SELECT COUNT(*) as count FROM users')
    user_count = cursor.fetchone()['count']
    conn.close()

    # Pehli baar setup: Admin account nahi hai toh registration par bhejega
    if user_count == 0:
        return redirect(url_for('register_admin'))

    if 'username' not in session:
        return redirect(url_for('login'))

    conn = get_db()
    cursor = conn.cursor()
    bots = cursor.execute('SELECT * FROM bots').fetchall()
    vps_list = cursor.execute('SELECT * FROM vps').fetchall()
    conn.close()

    return render_template('index.html', user=session['username'], role=session.get('role'), bots=bots, vps_list=vps_list)

@app.route('/register-admin', methods=['GET', 'POST'])
def register_admin():
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('SELECT COUNT(*) as count FROM users')
    user_count = cursor.fetchone()['count']

    if user_count > 0:
        conn.close()
        return redirect(url_for('login'))

    if request.method == 'POST':
        username = request.form['username']
        password = generate_password_hash(request.form['password'])
        cursor.execute('INSERT INTO users (username, password, role) VALUES (?, ?, ?)', (username, password, 'admin'))
        conn.commit()
        conn.close()
        return redirect(url_for('login'))

    conn.close()
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>CJH Panel - Create Admin</title>
        <style>
            body { font-family: sans-serif; background: #0d1117; color: #fff; display: flex; justify-content: center; align-items: center; height: 100vh; margin:0; }
            form { background: #161b22; padding: 30px; border-radius: 10px; border: 1px solid #30363d; display: flex; flex-direction: column; gap: 15px; width: 320px; }
            input, button { padding: 10px; border-radius: 6px; border: 1px solid #30363d; background: #0d1117; color: white; }
            button { background: #238636; border: none; cursor: pointer; font-weight: bold; }
        </style>
    </head>
    <body>
        <form method="POST">
            <h2>CJH Panel Admin Setup</h2>
            <input type="text" name="username" placeholder="Admin Username" required>
            <input type="password" name="password" placeholder="Admin Password" required>
            <button type="submit">Create Admin Account</button>
        </form>
    </body>
    </html>
    '''

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']

        conn = get_db()
        cursor = conn.cursor()
        user = cursor.execute('SELECT * FROM users WHERE username = ?', (username,)).fetchone()
        conn.close()

        if user and check_password_hash(user['password'], password):
            session['username'] = user['username']
            session['role'] = user['role']
            return redirect(url_for('index'))
        return "Invalid Username or Password"

    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>CJH Panel - Login</title>
        <style>
            body { font-family: sans-serif; background: #0d1117; color: #fff; display: flex; justify-content: center; align-items: center; height: 100vh; margin:0; }
            form { background: #161b22; padding: 30px; border-radius: 10px; border: 1px solid #30363d; display: flex; flex-direction: column; gap: 15px; width: 320px; }
            input, button { padding: 10px; border-radius: 6px; border: 1px solid #30363d; background: #0d1117; color: white; }
            button { background: #1f6feb; border: none; cursor: pointer; font-weight: bold; }
        </style>
    </head>
    <body>
        <form method="POST">
            <h2>CJH Panel Login</h2>
            <input type="text" name="username" placeholder="Username" required>
            <input type="password" name="password" placeholder="Password" required>
            <button type="submit">Login</button>
        </form>
    </body>
    </html>
    '''

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/add-bot', methods=['POST'])
def add_bot():
    if 'username' not in session: return redirect(url_for('login'))
    name = request.form['name']
    cmd = request.form['cmd']
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('INSERT INTO bots (name, cmd) VALUES (?, ?)', (name, cmd))
    conn.commit()
    conn.close()
    return redirect(url_for('index'))

@app.route('/create-vps', methods=['POST'])
def create_vps():
    if 'username' not in session or session.get('role') != 'admin':
        return "Unauthorized", 403

    vps_name = request.form['vps_name']
    ram = request.form['ram']
    vcpu = request.form['vcpu']

    cmd = f"virt-install --name {vps_name} --memory {ram} --vcpus {vcpu} --disk size=10 --os-variant ubuntu22.04 --import --noautoconsole"
    try:
        subprocess.Popen(cmd, shell=True)
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute('INSERT INTO vps (name, ram, vcpu, status) VALUES (?, ?, ?, ?)', (vps_name, ram, vcpu, 'running'))
        conn.commit()
        conn.close()
    except Exception as e:
        return str(e)

    return redirect(url_for('index'))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
