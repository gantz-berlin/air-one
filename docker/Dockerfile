# Build from the repo root:
#   docker build --platform linux/amd64 -f docker/Dockerfile -t air-one-dbt .
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DBT_PROJECT_DIR=/app/dbt \
    DBT_PROFILES_DIR=/app/dbt

WORKDIR /app

COPY docker/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY dbt/ /app/dbt/
COPY docker/entrypoint.sh /app/entrypoint.sh

RUN chmod +x /app/entrypoint.sh \
    && useradd --create-home --uid 1000 dbt \
    && chown -R dbt:dbt /app

USER dbt
WORKDIR /app/dbt

ENTRYPOINT ["/app/entrypoint.sh"]
