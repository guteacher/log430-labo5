FROM python:3.11-slim

WORKDIR /app
COPY locustfiles/ /mnt/locust/

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["python", "src/store_manager.py"]