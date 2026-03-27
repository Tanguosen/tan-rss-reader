#!/bin/bash
cd "$(dirname "$0")/.."
export PYTHONPATH="."
celery -A app.celery_app worker --loglevel=info
