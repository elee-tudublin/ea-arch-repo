FROM python:3.11-slim
WORKDIR /app

COPY services/post-svc/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY services/common /app/common
RUN pip install -e /app/common

COPY services/post-svc/app /app/app

ENV PYTHONUNBUFFERED=1
EXPOSE 8081
CMD ["uvicorn", "app.main:app", "--host=0.0.0.0", "--port=8081"]
