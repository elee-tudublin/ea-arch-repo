FROM python:3.11-slim
WORKDIR /app

COPY workers/moderation-consumer/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY services/common /app/common
RUN pip install -e /app/common

COPY workers/moderation-consumer/app /app/app

ENV PYTHONUNBUFFERED=1
CMD ["python", "-m", "app.main"]
