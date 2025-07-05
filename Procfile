web: gunicorn livestream_project.wsgi:application --bind 0.0.0.0:$PORT --workers 3 --timeout 120
worker: celery -A livestream_project worker -l info
beat: celery -A livestream_project beat -l info
