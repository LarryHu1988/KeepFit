FROM python:3.13-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 KEEPFIT_MODE=production KEEPFIT_DATA_DIR=/data
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt && useradd -u 10001 -r keepfit
COPY keepfit_model ./keepfit_model
USER 10001:10001
EXPOSE 8765
CMD ["python", "-m", "keepfit_model", "--host", "0.0.0.0", "--data-dir", "/data"]
