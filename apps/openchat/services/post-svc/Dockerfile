FROM python:3.11-slim

WORKDIR /app

# Copy and install service requirements
COPY post-svc/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# Copy and install shared common package
COPY common /app/common
RUN pip install -e /app/common

# Copy service code
COPY post-svc/app /app/app

ENV PYTHONUNBUFFERED=1
EXPOSE 8081

CMD ["uvicorn", "app.main:app", "--host=0.0.0.0", "--port=8081"]