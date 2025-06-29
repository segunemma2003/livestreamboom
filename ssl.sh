#!/bin/bash

echo "🐍 Backend SSL Setup (Django Only)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MACHINE_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
echo -e "${GREEN}🌐 Machine IP: $MACHINE_IP${NC}"

echo -e "\n${BLUE}🧹 Step 1: Clean Backend SSL Files${NC}"
pkill -f "manage.py runserver" 2>/dev/null || true
pkill -f "runserver_plus" 2>/dev/null || true
pkill -f "gunicorn" 2>/dev/null || true
lsof -ti:8000 | xargs kill -9 2>/dev/null || true
lsof -ti:8443 | xargs kill -9 2>/dev/null || true
sleep 2
echo -e "${GREEN}✅ Backend cleanup complete${NC}"

echo -e "\n${BLUE}📋 Step 2: Check/Install Backend SSL Dependencies${NC}"
echo "Installing backend SSL dependencies..."
pip install gunicorn gevent-websocket 2>/dev/null || true
pip install django-extensions pyOpenSSL 2>/dev/null || true

# Check if mkcert is available
if ! command -v mkcert &> /dev/null; then
    echo "Installing mkcert..."
    brew install mkcert
    mkcert -install
fi

echo -e "${GREEN}✅ Backend dependencies installed${NC}"

echo -e "\n${BLUE}📄 Step 3: Generate Backend SSL Certificates${NC}"
# Check if frontend certificates exist, use them if available
if [[ -f "frontend-cert.pem" && -f "frontend-key.pem" ]]; then
    echo -e "${YELLOW}📋 Using existing frontend certificates for backend${NC}"
    cp frontend-cert.pem backend-cert.pem
    cp frontend-key.pem backend-key.pem
else
    echo "Generating dedicated backend certificates..."
    mkcert -key-file backend-key.pem -cert-file backend-cert.pem localhost 127.0.0.1 ::1 $MACHINE_IP *.local
fi

if [[ -f "backend-cert.pem" && -f "backend-key.pem" ]]; then
    echo -e "${GREEN}✅ Backend certificates ready:${NC}"
    echo "  📄 Certificate: backend-cert.pem"
    echo "  🔑 Private Key: backend-key.pem"
else
    echo -e "${RED}❌ Backend certificate generation failed${NC}"
    exit 1
fi

echo -e "\n${BLUE}📋 Step 4: Update Django Settings for SSL${NC}"
cat > backend_ssl_settings.py << EOF
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
    "https://$MACHINE_IP:3000",
    "http://localhost:3000",  # Allow HTTP frontend too
    "http://$MACHINE_IP:3000",
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
EOF

echo -e "${GREEN}✅ Backend SSL settings template created${NC}"
echo -e "${YELLOW}📝 Add the contents of backend_ssl_settings.py to your Django settings.py${NC}"

echo -e "\n${BLUE}📋 Step 5: Create Backend SSL Startup Scripts${NC}"

# Method 1: Gunicorn (Recommended)
cat > start_backend_ssl_gunicorn.sh << EOF
#!/bin/bash

echo "🐍 Starting Django Backend with SSL (Gunicorn)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

MACHINE_IP=\$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print \$2}')

# Kill existing backend processes
echo "🧹 Cleaning up existing Django processes..."
pkill -f gunicorn 2>/dev/null || true
pkill -f "manage.py runserver" 2>/dev/null || true
lsof -ti:8443 | xargs kill -9 2>/dev/null || true
sleep 2

# Verify backend certificates exist
if [[ ! -f "backend-cert.pem" || ! -f "backend-key.pem" ]]; then
    echo -e "\${RED}❌ Backend SSL certificates not found\${NC}"
    echo "Run the backend SSL setup script first"
    exit 1
fi

echo -e "\${BLUE}🚀 Starting Django with Gunicorn HTTPS on port 8443...\${NC}"

# Start Django with Gunicorn SSL
gunicorn livestream_service.wsgi:application \\
    --bind 0.0.0.0:8443 \\
    --certfile=backend-cert.pem \\
    --keyfile=backend-key.pem \\
    --worker-class=gevent \\
    --worker-connections=1000 \\
    --workers=1 \\
    --reload \\
    --access-logfile=- \\
    --error-logfile=- &

DJANGO_PID=\$!

sleep 5

if lsof -Pi :8443 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "\${GREEN}✅ Django HTTPS backend started successfully!\${NC}"
    echo -e "\${BLUE}📱 Backend Access URLs:\${NC}"
    echo "  • Local: https://localhost:8443"
    echo "  • Network: https://\$MACHINE_IP:8443"
    echo "  • API Test: https://\$MACHINE_IP:8443/api/v1/livestream/test-connection/"
    echo ""
    echo -e "\${YELLOW}📋 Backend SSL Notes:\${NC}"
    echo "  • Django HTTPS running on port 8443"
    echo "  • HTTP version still available on port 8000 (if running)"
    echo "  • CORS configured for both HTTP and HTTPS frontends"
    echo ""
    echo "Django HTTPS PID: \$DJANGO_PID"
    echo "\$DJANGO_PID" > django_backend_ssl.pid
    
    # Test SSL API
    echo -e "\${BLUE}🧪 Testing backend SSL API...\${NC}"
    if curl -k -s "https://localhost:8443/api/v1/livestream/test-connection/" >/dev/null 2>&1; then
        echo -e "\${GREEN}✅ Backend HTTPS API responding\${NC}"
    else
        echo -e "\${YELLOW}⚠️ API test failed, but server is running\${NC}"
    fi
    
    cleanup() {
        echo -e "\\n🛑 Stopping Django HTTPS backend..."
        kill \$DJANGO_PID 2>/dev/null || true
        rm -f django_backend_ssl.pid 2>/dev/null || true
        echo "✅ Django backend stopped"
        exit 0
    }
    
    trap cleanup INT TERM
    
    echo -e "\\n\${GREEN}💡 Press Ctrl+C to stop Django HTTPS backend\${NC}"
    wait
    
else
    echo -e "\${RED}❌ Django HTTPS backend failed to start\${NC}"
    echo -e "\${YELLOW}📋 Check the error output above\${NC}"
    kill \$DJANGO_PID 2>/dev/null || true
    exit 1
fi
EOF

chmod +x start_backend_ssl_gunicorn.sh

# Method 2: runserver_plus (Alternative)
cat > start_backend_ssl_runserver.sh << EOF
#!/bin/bash

echo "🐍 Starting Django Backend with SSL (runserver_plus)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

MACHINE_IP=\$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print \$2}')

# Kill existing processes
pkill -f "runserver_plus" 2>/dev/null || true
pkill -f "manage.py runserver" 2>/dev/null || true
lsof -ti:8443 | xargs kill -9 2>/dev/null || true
sleep 2

# Verify certificates and dependencies
if [[ ! -f "backend-cert.pem" || ! -f "backend-key.pem" ]]; then
    echo -e "\${RED}❌ Backend certificates not found\${NC}"
    exit 1
fi

# Check django-extensions
if ! python -c "import django_extensions" 2>/dev/null; then
    echo "Installing django-extensions..."
    pip install django-extensions Werkzeug pyOpenSSL
fi

echo -e "\${BLUE}🚀 Starting Django with runserver_plus HTTPS...\${NC}"

python manage.py runserver_plus 0.0.0.0:8443 \\
    --cert-file backend-cert.pem \\
    --key-file backend-key.pem \\
    --nopin &

DJANGO_PID=\$!

sleep 5

if lsof -Pi :8443 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "\${GREEN}✅ Django HTTPS backend (runserver_plus) started!\${NC}"
    echo -e "\${BLUE}📱 Access: https://\$MACHINE_IP:8443\${NC}"
    echo "Django PID: \$DJANGO_PID"
    echo "\$DJANGO_PID" > django_runserver_ssl.pid
    
    cleanup() {
        kill \$DJANGO_PID 2>/dev/null || true
        rm -f django_runserver_ssl.pid 2>/dev/null || true
        exit 0
    }
    
    trap cleanup INT TERM
    wait
else
    echo -e "\${RED}❌ runserver_plus failed to start\${NC}"
    kill \$DJANGO_PID 2>/dev/null || true
    exit 1
fi
EOF

chmod +x start_backend_ssl_runserver.sh

# Method 3: HTTP Fallback
cat > start_backend_http.sh << EOF
#!/bin/bash

echo "🐍 Starting Django Backend with HTTP (No SSL)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

MACHINE_IP=\$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print \$2}')

# Kill existing processes
pkill -f "manage.py runserver" 2>/dev/null || true
lsof -ti:8000 | xargs kill -9 2>/dev/null || true
sleep 2

echo -e "\${BLUE}🚀 Starting Django HTTP backend on port 8000...\${NC}"

python manage.py runserver 0.0.0.0:8000 &
DJANGO_PID=\$!

sleep 3

if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "\${GREEN}✅ Django HTTP backend started!\${NC}"
    echo -e "\${BLUE}📱 Backend URLs:\${NC}"
    echo "  • Local: http://localhost:8000"
    echo "  • Network: http://\$MACHINE_IP:8000"
    echo "  • API Test: http://\$MACHINE_IP:8000/api/v1/livestream/test-connection/"
    echo ""
    echo -e "\${BLUE}💡 HTTP Backend Benefits:\${NC}"
    echo "  • No SSL certificate issues"
    echo "  • Works with HTTPS frontend via CORS"
    echo "  • Simpler debugging"
    echo ""
    echo "Django HTTP PID: \$DJANGO_PID"
    echo "\$DJANGO_PID" > django_backend_http.pid
    
    cleanup() {
        echo -e "\\n🛑 Stopping Django HTTP backend..."
        kill \$DJANGO_PID 2>/dev/null || true
        rm -f django_backend_http.pid 2>/dev/null || true
        echo "✅ Django backend stopped"
        exit 0
    }
    
    trap cleanup INT TERM
    
    echo -e "\\n\${GREEN}💡 Press Ctrl+C to stop Django HTTP backend\${NC}"
    wait
else
    echo -e "\${RED}❌ Django HTTP backend failed to start\${NC}"
    exit 1
fi
EOF

chmod +x start_backend_http.sh

echo -e "${GREEN}✅ Backend startup scripts created${NC}"

echo -e "\n${BLUE}📋 Step 6: Create Backend Test Script${NC}"
cat > test_backend_ssl.sh << 'EOF'
#!/bin/bash

echo "🧪 Testing Backend SSL Setup"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

MACHINE_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

echo -e "${BLUE}🔍 Checking backend SSL certificates...${NC}"
if [[ -f "backend-cert.pem" && -f "backend-key.pem" ]]; then
    echo -e "${GREEN}✅ Backend certificates found${NC}"
else
    echo -e "${RED}❌ Backend certificates missing${NC}"
    echo "Run: ./backend_ssl_setup.sh"
    exit 1
fi

echo -e "\n${BLUE}🧪 Testing backend SSL APIs...${NC}"

# Test HTTPS API
if curl -k -s "https://localhost:8443/api/v1/livestream/test-connection/" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Backend HTTPS API responding${NC}"
else
    echo -e "${YELLOW}⚠️ Backend HTTPS API not responding${NC}"
    echo "Start backend SSL: ./start_backend_ssl_gunicorn.sh"
fi

# Test HTTP API (fallback)
if curl -s "http://localhost:8000/api/v1/livestream/test-connection/" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Backend HTTP API responding${NC}"
else
    echo -e "${YELLOW}⚠️ Backend HTTP API not responding${NC}"
    echo "Start backend HTTP: ./start_backend_http.sh"
fi

echo -e "\n${BLUE}📱 Backend URLs:${NC}"
echo "  • HTTPS: https://$MACHINE_IP:8443"
echo "  • HTTP: http://$MACHINE_IP:8000"

echo -e "\n${BLUE}🎯 Backend is ready for your BoomSnap frontend!${NC}"
EOF

chmod +x test_backend_ssl.sh

echo -e "${GREEN}✅ Backend test script created${NC}"

echo -e "\n${GREEN}🎉 Backend SSL Setup Complete!${NC}"

echo -e "\n${BLUE}📋 Backend Quick Start Options:${NC}"
echo ""
echo -e "${YELLOW}Option 1: Django HTTPS with Gunicorn (Recommended)${NC}"
echo "  ./start_backend_ssl_gunicorn.sh"
echo "  Backend runs on: https://$MACHINE_IP:8443"
echo ""
echo -e "${YELLOW}Option 2: Django HTTPS with runserver_plus${NC}"
echo "  ./start_backend_ssl_runserver.sh"
echo "  Backend runs on: https://$MACHINE_IP:8443"
echo ""
echo -e "${YELLOW}Option 3: Django HTTP (Simpler)${NC}"
echo "  ./start_backend_http.sh"
echo "  Backend runs on: http://$MACHINE_IP:8000"

echo -e "\n${BLUE}📋 Test Backend:${NC}"
echo "  ./test_backend_ssl.sh"

echo -e "\n${BLUE}📁 Backend Files Created:${NC}"
echo "  • backend-cert.pem (Backend SSL certificate)"
echo "  • backend-key.pem (Backend SSL private key)"
echo "  • backend_ssl_settings.py (Django SSL settings)"
echo "  • start_backend_ssl_gunicorn.sh (Gunicorn HTTPS)"
echo "  • start_backend_ssl_runserver.sh (runserver_plus HTTPS)"
echo "  • start_backend_http.sh (Simple HTTP fallback)"
echo "  • test_backend_ssl.sh (Backend testing)"

echo -e "\n${YELLOW}📝 Update Your React App.tsx:${NC}"
echo ""
echo "For HTTPS backend:"
echo "  const [backendUrl] = useState('https://$MACHINE_IP:8443')"
echo ""
echo "For HTTP backend:"
echo "  const [backendUrl] = useState('http://$MACHINE_IP:8000')"

echo -e "\n${GREEN}✨ Backend SSL Benefits:${NC}"
echo "  • ✅ Full HTTPS stack for production-like testing"
echo "  • ✅ Better CORS handling"
echo "  • ✅ More secure API communication"
echo "  • ✅ Works perfectly with HTTPS frontend"

echo -e "\n${BLUE}🎯 Your Django backend is ready for BoomSnap!${NC}"