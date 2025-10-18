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

# Run the app from the helloworld directory
CMD ["python", "helloworld/app.py"]
