#!/bin/bash

echo "🐍 Starting Django with HTTPS (Fixed runserver_plus)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

MACHINE_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

# Kill existing Django processes
echo "🧹 Cleaning up existing Django processes..."
pkill -f "manage.py runserver" 2>/dev/null || true
pkill -f "runserver_plus" 2>/dev/null || true
lsof -ti:8001 | xargs kill -9 2>/dev/null || true
sleep 2

# Check if certificates exist
if [[ ! -f "localhost+3-key.pem" || ! -f "localhost+3-key.pem" ]]; then
    echo -e "${RED}❌ Certificate files not found\033[0m"
    echo "Run the certificate fix script first"
    exit 1
fi

echo -e "${BLUE}🚀 Starting Django with HTTPS on port 8001...${NC}"

# Use runserver_plus with SSL
python manage.py runserver_plus 0.0.0.0:8001 \
    --cert-file localhost+3-key.pem \
    --key-file localhost+3-key.pem \
    --nopin &
DJANGO_PID=$!

sleep 5

if lsof -Pi :8001 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Django HTTPS server started successfully!${NC}"
    echo -e "${BLUE}📱 Access URLs:${NC}"
    echo "  • Local: https://localhost:8001"
    echo "  • Network: https://$MACHINE_IP:8001"
    echo "  • API Test: https://$MACHINE_IP:8001/api/v1/livestream/test-connection/"
    echo ""
    echo -e "${YELLOW}📋 Important Notes:${NC}"
    echo "  • Django HTTPS running on port 8001"
    echo "  • Update React app to use: https://$MACHINE_IP:8001"
    echo "  • Browser will show certificate warning - accept it"
    echo ""
    echo "Django HTTPS PID: $DJANGO_PID"
    echo "$DJANGO_PID" > django_https.pid
    
    # Cleanup function
    cleanup() {
        echo -e "\n🛑 Stopping Django HTTPS server..."
        kill $DJANGO_PID 2>/dev/null || true
        rm -f django_https.pid 2>/dev/null || true
        echo "✅ Django HTTPS server stopped"
        exit 0
    }
    
    trap cleanup INT TERM
    
    echo -e "\n${GREEN}💡 Press Ctrl+C to stop Django HTTPS server${NC}"
    wait
    
else
    echo -e "${RED}❌ Django HTTPS server failed to start${NC}"
    echo "Check the error output above"
    kill $DJANGO_PID 2>/dev/null || true
    exit 1
fi
