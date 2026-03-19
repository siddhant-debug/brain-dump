import requests
import json
from datetime import datetime

BASE_URL = "http://localhost:8000"
TOKEN = "YOUR_JWT_TOKEN" # Replace with valid token for testing

def test_health_sync():
    payload = {
        "readiness": "HIGH",
        "heart_rate": {"current": 72, "avg_24h": 68, "resting": 60},
        "hrv": {"current": 45, "avg_7d": 42},
        "sleep": {"total_hours": 8.0, "deep_hours": 2.0, "rem_hours": 1.5, "awake_hours": 0.5},
        "steps_today": 10000,
        "active_energy_kcal": 500.0,
        "fetched_at": datetime.now().isoformat()
    }
    
    headers = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}
    
    print("Testing POST /api/health/context...")
    response = requests.post(f"{BASE_URL}/api/health/context", headers=headers, json=payload)
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}")
    
    print("\nTesting GET /api/health/latest...")
    response = requests.get(f"{BASE_URL}/api/health/latest", headers=headers)
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}")

if __name__ == "__main__":
    print("HealthKit Integration Verification Script")
    # This script requires a running server and valid token.
    # Manual verification via SQL is also recommended as per plan.
