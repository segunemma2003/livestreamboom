# Update your livestream/views.py with these CORS headers for HTTPS

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.views.decorators.clickjacking import xframe_options_exempt
import json
import time
import jwt
import requests

# Add CORS headers decorator
def add_cors_headers(response):
    response["Access-Control-Allow-Origin"] = "*"  # Or specific origins
    response["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    response["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    response["Access-Control-Allow-Credentials"] = "true"
    return response

@csrf_exempt
@require_http_methods(["POST", "OPTIONS"])
def generate_token(request):
    if request.method == "OPTIONS":
        response = JsonResponse({})
        return add_cors_headers(response)
    
    # Your existing generate_token code here...
    # Make sure to add CORS headers to the response:
    response = JsonResponse({
        'token': token,
        'identity': identity,
        'room_name': room_name,
        'role': role,
        'server_url': LIVEKIT_WS_URL,
        'expires_in': 24 * 60 * 60
    })
    return add_cors_headers(response)

@csrf_exempt  
@require_http_methods(["GET", "OPTIONS"])
def test_connection(request):
    if request.method == "OPTIONS":
        response = JsonResponse({})
        return add_cors_headers(response)
        
    # Your existing test_connection code here...
    # Make sure to add CORS headers to the response:
    response = JsonResponse({
        'django_backend': {
            'status': 'connected',
            'timestamp': int(time.time())
        },
        'connection_test': {
            'status': 'connected',
            'server_url': LIVEKIT_HTTP_URL,
            'ws_url': LIVEKIT_WS_URL,
        }
    })
    return add_cors_headers(response)
