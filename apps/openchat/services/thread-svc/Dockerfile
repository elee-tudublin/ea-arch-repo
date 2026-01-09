FROM python:3.11-slim

WORKDIR /app

# Copy and install service requirements
COPY thread-svc/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# Copy and install shared common package
COPY common /app/common
RUN pip install -e /app/common

# Copy service code
COPY thread-svc/app /app/app

ENV PYTHONUNBUFFERED=1
EXPOSE 8080

CMD ["uvicorn", "app.main:app", "--host=0.0.0.0", "--port=8080"]