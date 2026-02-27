FROM python:3.11-slim

# Install git and required dependencies
RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Clone the repository
RUN git clone https://github.com/x011/smtp-tunnel-proxy.git .

# Install Python requirements
RUN pip install --no-cache-dir -r requirements.txt

# Ensure management scripts are executable
RUN chmod +x smtp-tunnel-*

# Copy the generated startup script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Define a volume for persistent storage across Zeabur redeployments
VOLUME ["/data"]

# Entrypoint via startup script
ENTRYPOINT ["/app/start.sh"]
