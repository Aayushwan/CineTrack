# Use lightweight official Python 3.11 image
FROM python:3.11-slim

# Prevent Python from writing bytecode (.pyc) and buffer logs
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install system dependencies required for PostgreSQL / asyncpg
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend source code
COPY . .

# Expose default FastAPI port
EXPOSE 8000

# Start Uvicorn bound to 0.0.0.0 so host machine can connect
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]