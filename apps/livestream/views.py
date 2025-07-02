import json
import time
import jwt
import requests
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.conf import settings

# LiveKit configuration from settings or fallback to your actual server
LIVEKIT_API_KEY = getattr(settings, 'LIVEKIT_CONFIG', {}).get('API_KEY', '2f96aaaa91727f979ee756cfbd6f6e56')
LIVEKIT_API_SECRET = getattr(settings, 'LIVEKIT_CONFIG', {}).get('API_SECRET', '2cff236bc97b877758be4e2e58dc71abf0791851762ef64d3f1587e43e872416')
LIVEKIT_WS_URL = getattr(settings, 'LIVEKIT_CONFIG', {}).get('WS_URL', 'wss://livekit-server.boomsnap.com')
LIVEKIT_HTTP_URL = getattr(settings, 'LIVEKIT_CONFIG', {}).get('HTTP_URL', 'https://livekit-server.boomsnap.com')

# Fallback to IP if domain doesn't work
LIVEKIT_IP_URL = "http://3.89.23.33:7880"

def generate_access_token(identity, room_name, role="audience"):
    """
    Generate LiveKit access token for your actual server
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
            'server_config': {
                'ws_url': LIVEKIT_WS_URL,
                'http_url': LIVEKIT_HTTP_URL,
                'rtc_port': 7881,
                'udp_range': '50000-60000'
            },
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
    Test connection to your LiveKit server
    """
    try:
        # Test both domain and IP
        test_results = {}
        
        # Test domain connection
        try:
            response = requests.get(f"{LIVEKIT_HTTP_URL}/", timeout=5)
            test_results['domain'] = {
                'status': 'connected' if response.status_code in [200, 404, 401] else 'failed',
                'url': LIVEKIT_HTTP_URL,
                'response_code': response.status_code
            }
        except requests.exceptions.RequestException as e:
            test_results['domain'] = {
                'status': 'failed',
                'url': LIVEKIT_HTTP_URL,
                'error': str(e)
            }
        
        # Test IP connection
        try:
            response = requests.get(f"{LIVEKIT_IP_URL}/", timeout=5)
            test_results['ip'] = {
                'status': 'connected' if response.status_code in [200, 404, 401] else 'failed',
                'url': LIVEKIT_IP_URL,
                'response_code': response.status_code
            }
        except requests.exceptions.RequestException as e:
            test_results['ip'] = {
                'status': 'failed',
                'url': LIVEKIT_IP_URL,
                'error': str(e)
            }
        
        return JsonResponse({
            'django_backend': {
                'status': 'connected',
                'timestamp': int(time.time())
            },
            'livekit_tests': test_results,
            'config': {
                'api_key': LIVEKIT_API_KEY,
                'domain_url': LIVEKIT_HTTP_URL,
                'ip_url': LIVEKIT_IP_URL,
                'ws_url': LIVEKIT_WS_URL,
                'rtc_port': 7881,
                'udp_range': '50000-60000'
            }
        })
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@csrf_exempt
@require_http_methods(["GET"])
def list_rooms(request):
    """
    List active rooms from your LiveKit server
    """
    try:
        # Generate admin token for API access
        admin_token = generate_access_token("admin", "", "host")
        
        headers = {
            'Authorization': f'Bearer {admin_token}',
            'Content-Type': 'application/json'
        }
        
        # Try domain first, fallback to IP
        for url in [LIVEKIT_HTTP_URL, LIVEKIT_IP_URL]:
            try:
                response = requests.get(f"{url}/twirp/livekit.RoomService/ListRooms", 
                                     headers=headers, timeout=10)
                if response.status_code == 200:
                    return JsonResponse({
                        'rooms': response.json().get('rooms', []),
                        'server_url': url,
                        'status': 'success'
                    })
            except requests.exceptions.RequestException:
                continue
        
        return JsonResponse({
            'rooms': [],
            'message': 'Could not connect to LiveKit server',
            'status': 'error'
        })
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@csrf_exempt
@require_http_methods(["GET"])
def list_participants(request, room_name):
    """
    List participants in a room
    """
    try:
        # Generate admin token for API access
        admin_token = generate_access_token("admin", room_name, "host")
        
        headers = {
            'Authorization': f'Bearer {admin_token}',
            'Content-Type': 'application/json'
        }
        
        data = {'room': room_name}
        
        # Try domain first, fallback to IP
        for url in [LIVEKIT_HTTP_URL, LIVEKIT_IP_URL]:
            try:
                response = requests.post(f"{url}/twirp/livekit.RoomService/ListParticipants", 
                                       headers=headers, json=data, timeout=10)
                if response.status_code == 200:
                    return JsonResponse({
                        'participants': response.json().get('participants', []),
                        'room_name': room_name,
                        'server_url': url,
                        'status': 'success'
                    })
            except requests.exceptions.RequestException:
                continue
        
        return JsonResponse({
            'participants': [],
            'room_name': room_name,
            'message': 'Could not connect to LiveKit server',
            'status': 'error'
        })
        
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)