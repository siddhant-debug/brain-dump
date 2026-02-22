# /backend/Dockerfile
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies (needed for compiling some python ML/DB packages)
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first to leverage Docker layer caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . .

# Ensure Python can find the 'app' module
ENV PYTHONPATH=/app

# Expose the API port
EXPOSE 8000

# Start Uvicorn pointing directly at the app directory
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
