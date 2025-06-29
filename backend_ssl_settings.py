# Add this to your livestream_service/settings.py for backend SSL

import os
from pathlib import Path

# Add to INSTALLED_APPS (if not already present)
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'corsheaders',
    'django_extensions',  # For SSL support
    'livestream',
]

# SSL Configuration for Backend
SECURE_SSL_REDIRECT = False  # Don't redirect in development
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')

# CORS Configuration for Backend SSL
CORS_ALLOWED_ORIGINS = [
    "https://localhost:3000",
    "https://127.0.0.1:3000",
    "https://192.168.1.170:3000",
    "http://localhost:3000",  # Allow HTTP frontend too
    "http://192.168.1.170:3000",
]

CORS_ALLOW_ALL_ORIGINS = False  # More secure with specific origins
CORS_ALLOW_CREDENTIALS = True

# Additional CORS headers for SSL backend
CORS_ALLOW_HEADERS = [
    'accept',
    'accept-encoding',
    'authorization',
    'content-type',
    'dnt',
    'origin',
    'user-agent',
    'x-csrftoken',
    'x-requested-with',
]

# Allow all hosts for development
ALLOWED_HOSTS = ['*']

# SSL Context for development
if DEBUG:
    import ssl
    ssl._create_default_https_context = ssl._create_unverified_context
