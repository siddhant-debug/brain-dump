import requests
import random
import string
import sys
import os

# Configuration
BASE_URL = "http://127.0.0.1:8000"
EMAIL_PREFIX = "test_user_"
PASSWORD = "password123"

def generate_random_string(length=8):
    return ''.join(random.choices(string.ascii_lowercase + string.digits, k=length))

def log(message, type="INFO"):
    print(f"[{type}] {message}")

def test_backend():
    print(f"🚀 Starting Backend Tests on {BASE_URL}...\n")
    
    # 1. AUTHENTICATION
    log("Testing Authentication...")
    
    # Signup
    email = f"{EMAIL_PREFIX}{generate_random_string()}@example.com"
    signup_data = {
        "email": email,
        "password": PASSWORD,
        "full_name": "Test User"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/auth/signup", json=signup_data)
        if response.status_code == 200:
            log(f"Signup successful: {email}", "SUCCESS")
        else:
            log(f"Signup failed: {response.text}", "ERROR")
            sys.exit(1)
    except Exception as e:
        log(f"Connection error: {e}", "CRITICAL")
        sys.exit(1)

    # Login
    login_data = {
        "email": email,
        "password": PASSWORD
    }
    response = requests.post(f"{BASE_URL}/auth/login", json=login_data)
    if response.status_code == 200:
        token = response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        log("Login successful. Token received.", "SUCCESS")
    else:
        log(f"Login failed: {response.text}", "ERROR")
        sys.exit(1)

    print("-" * 30)

    # 2. NOTES
    log("Testing Notes...")
    
    # Create Note
    note_content = f"This is a test note created at {generate_random_string()}"
    response = requests.post(f"{BASE_URL}/notes/", json={"content": note_content}, headers=headers)
    if response.status_code == 200:
        log("Note created successfully.", "SUCCESS")
    else:
        log(f"Failed to create note: {response.text}", "ERROR")

    # List Notes
    response = requests.get(f"{BASE_URL}/notes/", headers=headers)
    if response.status_code == 200:
        notes = response.json()
        if len(notes) > 0 and notes[0]["content"] == note_content:
             log(f"Notes listed successfully. Found {len(notes)} notes.", "SUCCESS")
        else:
             log("Notes listed but content mismatch or empty.", "WARNING")
    else:
        log(f"Failed to list notes: {response.text}", "ERROR")

    print("-" * 30)

    # 3. FILES
    log("Testing Files...")
    
    # Upload File
    filename = f"test_file_{generate_random_string()}.txt"
    file_content = "This is the content of the uploaded test file."
    files = {'file': (filename, file_content, 'text/plain')}
    
    response = requests.post(f"{BASE_URL}/files/upload", files=files, headers=headers)
    if response.status_code == 200:
         log(f"File uploaded successfully: {filename}", "SUCCESS")
    else:
         log(f"File upload failed: {response.text}", "ERROR")

    # List Files
    response = requests.get(f"{BASE_URL}/files/", headers=headers)
    if response.status_code == 200:
        files_list = response.json()
        log(f"Files listed successfully. Found {len(files_list)} files.", "SUCCESS")
    else:
        log(f"Failed to list files: {response.text}", "ERROR")

    print("-" * 30)
    
    # 4. RAG / BRAIN
    log("Testing RAG (Brain)...")
    
    # Upload to Brain
    brain_filename = f"brain_memory_{generate_random_string()}.txt"
    brain_content = "The capital of France is Paris. The airspeed velocity of an unladen swallow is about 24 miles per hour."
    files = {'file': (brain_filename, brain_content, 'text/plain')}
    
    response = requests.post(f"{BASE_URL}/chat/upload-to-brain", files=files, headers=headers)
    if response.status_code == 200:
        log("Uploaded to Brain successfully.", "SUCCESS")
    else:
        log(f"Failed to upload to Brain: {response.text}", "ERROR")

    # Chat
    query = "What is the capital of France?"
    response = requests.post(f"{BASE_URL}/chat/chat", json={"query": query}, headers=headers)
    if response.status_code == 200:
        answer = response.json().get("answer", "No answer found")
        log(f"Chat Query: '{query}'", "INFO")
        log(f"Chat Answer: '{answer}'", "SUCCESS")
    else:
        log(f"Chat failed: {response.text}", "ERROR")
    
    print("\n✅ All Tests Completed.")

if __name__ == "__main__":
    test_backend()
