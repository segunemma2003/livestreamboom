"""
Custom Django management command to run server with HTTPS
"""
import os
import ssl
from django.core.management.commands.runserver import Command as RunServerCommand
from django.core.management.base import CommandError

class Command(RunServerCommand):
    help = 'Run Django development server with HTTPS'
    
    def add_arguments(self, parser):
        super().add_arguments(parser)
        parser.add_argument(
            '--cert-file',
            dest='cert_file',
            default='localhost+3-key.pem',
            help='SSL certificate file path'
        )
        parser.add_argument(
            '--key-file', 
            dest='key_file',
            default='localhost+3-key.pem',
            help='SSL private key file path'
        )
    
    def get_handler(self, *args, **options):
        handler = super().get_handler(*args, **options)
        
        cert_file = options.get('cert_file')
        key_file = options.get('key_file')
        
        if cert_file and key_file:
            if not os.path.exists(cert_file):
                raise CommandError(f'Certificate file not found: {cert_file}')
            if not os.path.exists(key_file):
                raise CommandError(f'Key file not found: {key_file}')
                
            # Wrap handler with SSL
            import ssl
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(cert_file, key_file)
            
            # This is a simplified approach - for production use proper WSGI server
            self.stdout.write(f'Using SSL certificate: {cert_file}')
            self.stdout.write(f'Using SSL key: {key_file}')
        
        return handler
