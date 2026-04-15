import asyncio
import httpx
import json

async def run_test():
    url = "http://127.0.0.1:8000/chat/chat"
    payload = {
        "query": "whats up?",
        "location": None
    }
    
    # We need to simulate the Flutter app's authentication.
    # The endpoint requires a valid JWT token.
    # To bypass this for a pure performance test, we can use a known good token 
    # OR we can hit a test endpoint if one exists.
    # Since auth is required, let's grab the token from a local login first.
    
    print("Testing local RAG performance...")
    
    # First, login to get a token (assumes test user exists)
    login_url = "http://127.0.0.1:8000/auth/login"
    login_data = {"email": "siddhanttomar@hotmail.com", "password": "1aQbesti"}
    
    async with httpx.AsyncClient() as client:
        try:
            # Note: You may need to change these credentials if you don't have a test user
            print("1. Authenticating...")
            login_response = await client.post(login_url, json=login_data)
            
            if login_response.status_code != 200:
                print(f"Login failed: {login_response.text}")
                print("Please ensure you have a user 'test@example.com' with 'password123'")
                return
                
            token = login_response.json().get("access_token")
            headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
            
            print("2. Sending RAG Query (whats up?)...")
            # Set a massive timeout (120 seconds) so httpx doesn't kill it like Flutter did
            timeout = httpx.Timeout(120.0)
            
            # Use stream to read the SSE chunks as they arrive
            async with client.stream("POST", url, json=payload, headers=headers, timeout=timeout) as response:
                if response.status_code != 200:
                    print(f"Error: {response.status_code} - Stream failed to start")
                    return
                    
                print("3. Stream connected! Waiting for first chunk...")
                
                async for chunk in response.aiter_text():
                    if chunk.strip():
                        print(f"Received Chunk: {chunk.strip()}")
                        
            print("\nStream completed successfully!")
            print("Check your Uvicorn terminal for the millisecond timing logs!")
            
        except httpx.ReadTimeout:
            print("\nHTTPX Timeout Hit! The backend took longer than 120 seconds.")
        except Exception as e:
            print(f"\nError: {e}")

if __name__ == "__main__":
    asyncio.run(run_test())
