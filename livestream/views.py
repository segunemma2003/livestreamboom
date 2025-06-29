import json
import time
import jwt
import requests
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods

# LiveKit configuration for testing
LIVEKIT_API_KEY = "devkey"
LIVEKIT_API_SECRET = "secret"
LIVEKIT_WS_URL = "ws://192.168.1.170:7880"
LIVEKIT_HTTP_URL = "http://192.168.1.170:7880"

def generate_access_token(identity, room_name, role="audience"):
    """
    Generate LiveKit access token for testing
    """
    try:
        # Token payload
        now = int(time.time())
        exp = now + (24 * 60 * 60)  # 24 hours expiration
        
        payload = {
            "iss": LIVEKIT_API_KEY,
            "sub": identity,
            "iat": now,
            "exp": exp,
            "room": room_name,
        }
        
        # Add permissions based on role
        if role == "host":
            payload["video"] = {
                "room": room_name,
                "roomJoin": True,
                "roomList": True,
                "roomRecord": True,
                "roomAdmin": True,
                "roomCreate": True,
                "canPublish": True,
                "canSubscribe": True,
                "canPublishData": True,
            }
        else:  # audience
            payload["video"] = {
                "room": room_name,
                "roomJoin": True,
                "canSubscribe": True,
                "canPublishData": True,
            }
        
        # Generate JWT token
        token = jwt.encode(payload, LIVEKIT_API_SECRET, algorithm="HS256")
        return token
        
    except Exception as e:
        print(f"Token generation error: {e}")
        raise e

@csrf_exempt
@require_http_methods(["POST"])
def generate_token(request):
    """
    API endpoint to generate LiveKit access tokens
    """
    try:
        data = json.loads(request.body)
        identity = data.get('identity')
        room_name = data.get('room_name')
        role = data.get('role', 'audience')
        
        if not identity or not room_name:
            return JsonResponse({
                'error': 'identity and room_name are required'
            }, status=400)
        
        # Generate token
        token = generate_access_token(identity, room_name, role)
        
        return JsonResponse({
            'token': token,
            'identity': identity,
            'room_name': room_name,
            'role': role,
            'server_url': LIVEKIT_WS_URL,
            'expires_in': 24 * 60 * 60  # 24 hours
        })
        
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON'}, status=400)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@csrf_exempt
@require_http_methods(["GET"])
def test_connection(request):
    """
    Test connection to LiveKit server
    """
    try:
        # Test HTTP connection to LiveKit server
        response = requests.get(
            f"{LIVEKIT_HTTP_URL}/", 
            timeout=5
        )
        
        livekit_status = "connected" if response.status_code in [200, 404, 401] else "failed"
        
        return JsonResponse({
            'django_backend': {
                'status': 'connected',
                'timestamp': int(time.time())
            },
            'connection_test': {
                'status': livekit_status,
                'server_url': LIVEKIT_HTTP_URL,
                'ws_url': LIVEKIT_WS_URL,
                'response_code': response.status_code
            },
            'config': {
                'api_key': LIVEKIT_API_KEY,
                'server_urls': {
                    'http': LIVEKIT_HTTP_URL,
                    'websocket': LIVEKIT_WS_URL
                }
            }
        })
        
    except requests.exceptions.RequestException as e:
        return JsonResponse({
            'django_backend': {
                'status': 'connected',
                'timestamp': int(time.time())
            },
            'connection_test': {
                'status': 'failed',
                'error': str(e),
                'server_url': LIVEKIT_HTTP_URL,
                'ws_url': LIVEKIT_WS_URL
            }
        })
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@csrf_exempt
@require_http_methods(["GET"])
def list_rooms(request):
    """
    List active rooms (for testing - simplified version)
    """
    return JsonResponse({
        'rooms': [],
        'message': 'Room listing available',
        'server_url': LIVEKIT_HTTP_URL
    })

@csrf_exempt
@require_http_methods(["GET"])
def list_participants(request, room_name):
    """
    List participants in a room (for testing)
    """
    return JsonResponse({
        'participants': [],
        'room_name': room_name,
        'message': 'Participant listing available'
    })
