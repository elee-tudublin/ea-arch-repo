FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY ../common /app/common
RUN pip install -e /app/common

COPY app /app/app

ENV PYTHONUNBUFFERED=1
EXPOSE 8081

CMD ["uvicorn", "app.main:app", "--host=0.0.0.0", "--port=8081"]
