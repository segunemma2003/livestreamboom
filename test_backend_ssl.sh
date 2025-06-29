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
