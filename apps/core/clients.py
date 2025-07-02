import requests
import jwt
import logging
from django.conf import settings
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)

class MainAppClient:
    """Client for communicating with main Django app"""
    
    def __init__(self):
        self.base_url = settings.MAIN_APP_CONFIG['BASE_URL']
        self.timeout = settings.MAIN_APP_CONFIG['TIMEOUT']
    
    def get_service_token(self):
        """Generate service token for authentication"""
        payload = {
            'service': 'livestream_service',
            'exp': datetime.utcnow() + timedelta(hours=1),
            'iat': datetime.utcnow(),
        }
        return jwt.encode(payload, settings.SECRET_KEY, algorithm='HS256')
    
    def get_headers(self):
        """Get headers for API requests"""
        return {
            'Authorization': f'Service {self.get_service_token()}',
            'Content-Type': 'application/json',
        }
    
    def get_user(self, user_id):
        """Get user details from main app"""
        try:
            response = requests.get(
                f"{self.base_url}/api/internal/users/{user_id}/",
                headers=self.get_headers(),
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                return response.json()
            else:
                logger.error(f"Failed to get user {user_id}: {response.status_code}")
                return None
                
        except requests.RequestException as e:
            logger.error(f"Error getting user {user_id}: {str(e)}")
            return None
    
    def verify_user_subscription(self, user_id, creator_id):
        """Check if user is subscribed to creator"""
        try:
            response = requests.get(
                f"{self.base_url}/api/internal/subscriptions/check/",
                params={'user_id': user_id, 'creator_id': creator_id},
                headers=self.get_headers(),
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                return response.json().get('is_subscribed', False)
            return False
            
        except requests.RequestException as e:
            logger.error(f"Error checking subscription: {str(e)}")
            return False
    
    def get_user_wallet(self, user_id):
        """Get user's wallet balance"""
        try:
            response = requests.get(
                f"{self.base_url}/api/internal/wallets/{user_id}/",
                headers=self.get_headers(),
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                return response.json()
            return None
            
        except requests.RequestException as e:
            logger.error(f"Error getting wallet for user {user_id}: {str(e)}")
            return None
    
    def deduct_user_coins(self, user_id, amount, description):
        """Deduct coins from user's wallet"""
        try:
            response = requests.post(
                f"{self.base_url}/api/internal/wallets/{user_id}/deduct/",
                json={
                    'amount': amount,
                    'description': description,
                    'transaction_type': 'gift_sent'
                },
                headers=self.get_headers(),
                timeout=self.timeout
            )
            
            return response.status_code == 200
            
        except requests.RequestException as e:
            logger.error(f"Error deducting coins: {str(e)}")
            return False
    
    def add_creator_earnings(self, creator_id, amount, description):
        """Add earnings to creator's wallet"""
        try:
            response = requests.post(
                f"{self.base_url}/api/internal/wallets/{creator_id}/add/",
                json={
                    'amount': amount,
                    'description': description,
                    'transaction_type': 'gift_received'
                },
                headers=self.get_headers(),
                timeout=self.timeout
            )
            
            return response.status_code == 200
            
        except requests.RequestException as e:
            logger.error(f"Error adding creator earnings: {str(e)}")
            return False
    
    def notify_user(self, user_id, notification_type, data):
        """Send notification to user via main app"""
        try:
            response = requests.post(
                f"{self.base_url}/api/internal/notifications/",
                json={
                    'user_id': user_id,
                    'type': notification_type,
                    'data': data
                },
                headers=self.get_headers(),
                timeout=self.timeout
            )
            
            return response.status_code == 201
            
        except requests.RequestException as e:
            logger.error(f"Error sending notification: {str(e)}")
            return False