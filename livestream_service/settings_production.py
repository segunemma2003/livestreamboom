import os
from .settings import *

DEBUG = False
ALLOWED_HOSTS = [
    'your-app.elasticbeanstalk.com',
    'your-custom-domain.com',
    '*.amazonaws.com'
]

# Database
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('LIVESTREAM_DB_NAME'),
        'USER': os.environ.get('LIVESTREAM_DB_USER'),
        'PASSWORD': os.environ.get('LIVESTREAM_DB_PASSWORD'),
        'HOST': os.environ.get('LIVESTREAM_DB_HOST'),
        'PORT': os.environ.get('LIVESTREAM_DB_PORT', '5432'),
    }
}

# Redis Configuration
REDIS_URL = os.environ.get('REDIS_URL')

# Celery Configuration
CELERY_BROKER_URL = os.environ.get('CELERY_BROKER_URL', REDIS_URL)
CELERY_RESULT_BACKEND = os.environ.get('CELERY_RESULT_BACKEND', REDIS_URL)

# Static Files (S3)
DEFAULT_FILE_STORAGE = 'storages.backends.s3boto3.S3Boto3Storage'
STATICFILES_STORAGE = 'storages.backends.s3boto3.StaticS3Boto3Storage'

AWS_ACCESS_KEY_ID = os.environ.get('AWS_ACCESS_KEY_ID')
AWS_SECRET_ACCESS_KEY = os.environ.get('AWS_SECRET_ACCESS_KEY')
AWS_STORAGE_BUCKET_NAME = os.environ.get('AWS_STORAGE_BUCKET_NAME')
AWS_S3_REGION_NAME = os.environ.get('AWS_S3_REGION_NAME', 'us-east-1')
AWS_S3_CUSTOM_DOMAIN = f'{AWS_STORAGE_BUCKET_NAME}.s3.amazonaws.com'
AWS_DEFAULT_ACL = 'public-read'

STATIC_URL = f'https://{AWS_S3_CUSTOM_DOMAIN}/static/'
MEDIA_URL = f'https://{AWS_S3_CUSTOM_DOMAIN}/media/'

# LiveKit Configuration
LIVEKIT_CONFIG = {
    'WS_URL': os.environ.get('LIVEKIT_WS_URL'),
    'HTTP_URL': os.environ.get('LIVEKIT_HTTP_URL'),
    'API_KEY': os.environ.get('LIVEKIT_API_KEY'),
    'API_SECRET': os.environ.get('LIVEKIT_API_SECRET'),
}

# Security
SECURE_SSL_REDIRECT = True
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')