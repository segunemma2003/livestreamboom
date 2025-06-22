from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from django.conf import settings
import jwt

class ServiceTokenAuthentication(BaseAuthentication):
    """Authentication for service-to-service communication"""
    
    def authenticate(self, request):
        auth_header = request.META.get('HTTP_AUTHORIZATION')
        if not auth_header or not auth_header.startswith('Service '):
            return None
        
        token = auth_header.split(' ')[1]
        
        try:
            # Verify service token
            payload = jwt.decode(
                token, 
                settings.SECRET_KEY, 
                algorithms=['HS256']
            )
            
            service_name = payload.get('service')
            if service_name == 'main_app':
                # Create a service user object
                return (ServiceUser(service_name), token)
                
        except jwt.InvalidTokenError:
            raise AuthenticationFailed('Invalid service token')
        
        return None

class ServiceUser:
    """Represents a service user for service-to-service calls"""
    
    def __init__(self, service_name):
        self.service_name = service_name
        self.is_authenticated = True
        self.is_service = True
    
    @property
    def id(self):
        return f"service_{self.service_name}"