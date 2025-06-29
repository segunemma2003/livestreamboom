# Add this to your livestream_service/settings.py

# Add to INSTALLED_APPS
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'corsheaders',
    'django_extensions',  # For runserver_plus
    'livestream',
]

# CORS Configuration for HTTPS
CORS_ALLOWED_ORIGINS = [
    "https://localhost:3000",
    "https://127.0.0.1:3000",
    "https://192.168.1.170:3000",
    "http://localhost:3000",
    "http://192.168.1.170:3000",
]

CORS_ALLOW_ALL_ORIGINS = False  # More secure
CORS_ALLOW_CREDENTIALS = True

# Allow all hosts for development
ALLOWED_HOSTS = ['*']

# Additional CORS headers
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

# SSL Configuration for development
if DEBUG:
    import ssl
    ssl._create_default_https_context = ssl._create_unverified_context
