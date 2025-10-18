# Use a lightweight Python base image
FROM python:3.12-slim

# Set the working directory
WORKDIR /app

# Copy dependency file and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose the port your app listens on (5000 is default for Flask)
EXPOSE 5000

# Healthcheck (adjust the endpoint if using something else or CLI app)
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl --fail http://localhost:5000/ || exit 1

# Run the app
CMD ["python", "hello.py"]
