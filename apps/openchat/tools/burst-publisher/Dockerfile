FROM python:3.11-slim
WORKDIR /app

COPY tools/burst-publisher/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY tools/burst-publisher/app /app/app
CMD ["python", "-m", "app.main"]
