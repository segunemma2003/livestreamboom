#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting LiveKit for Multi-Device Testing${NC}"

# Get the actual IP address of this machine
get_ip() {
    # Try to get the main network interface IP
    IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
    if [ -z "$IP" ]; then
        # Fallback method
        IP=$(hostname -I | awk '{print $1}' 2>/dev/null)
    fi
    if [ -z "$IP" ]; then
        # Another fallback
        IP="192.168.1.170"  # Your known IP
    fi
    echo $IP
}

MACHINE_IP=$(get_ip)
echo -e "${GREEN}🌐 Detected machine IP: $MACHINE_IP${NC}"

# Function to kill process on port
kill_port() {
    local port=$1
    local pids=$(lsof -ti:$port 2>/dev/null)
    if [ ! -z "$pids" ]; then
        echo -e "${YELLOW}🔧 Killing existing processes on port $port${NC}"
        echo $pids | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
}

# Clean up existing processes
echo -e "${BLUE}🧹 Cleaning up existing processes${NC}"
kill_port 7880
kill_port 7881
pkill -f livekit-server 2>/dev/null || true
sleep 2

# Create LiveKit config optimized for multi-device testing
echo -e "${BLUE}📝 Creating LiveKit config for multi-device testing${NC}"
cat > livekit.yaml << EOF
# LiveKit configuration for multi-device testing
port: 7880
bind_addresses:
  - "0.0.0.0"

# RTC configuration for cross-device connectivity
rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: true
  # Use the machine's actual IP for multi-device testing
  node_ip: "$MACHINE_IP"
  
# Disable TURN for local network testing
turn:
  enabled: false

# API Keys
keys:
  devkey: secret

# Room configuration
room:
  empty_timeout: 300
  max_participants: 1000

# Logging for debugging
logging:
  level: info
  json: false
EOF

echo -e "${GREEN}✅ LiveKit config created for IP: $MACHINE_IP${NC}"

# Show the config
echo -e "\n${BLUE}📋 LiveKit Configuration:${NC}"
cat livekit.yaml

# Start LiveKit server
echo -e "\n${BLUE}🎥 Starting LiveKit Server${NC}"
echo -e "${GREEN}🔧 Multi-device configuration:${NC}"
echo -e "  • Server IP: $MACHINE_IP"
echo -e "  • HTTP Port: 7880"
echo -e "  • RTC TCP Port: 7881"
echo -e "  • RTC UDP Range: 50000-60000"
echo -e "  • External IP: Enabled"

# Start LiveKit in background
nohup livekit-server --config livekit.yaml > livekit.log 2>&1 &
LIVEKIT_PID=$!

echo -e "${GREEN}✅ LiveKit server started (PID: $LIVEKIT_PID)${NC}"

# Wait and check startup
sleep 5

echo -e "\n${BLUE}📋 LiveKit startup logs:${NC}"
tail -10 livekit.log

# Check if LiveKit started successfully
if lsof -Pi :7880 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${GREEN}✅ LiveKit HTTP server running on $MACHINE_IP:7880${NC}"
else
    echo -e "${RED}❌ LiveKit failed to start${NC}"
    cat livekit.log
    exit 1
fi

# Start Django
echo -e "\n${BLUE}🐍 Starting Django Server${NC}"
python manage.py migrate --run-syncdb > /dev/null 2>&1
python manage.py runserver 0.0.0.0:8000 &
DJANGO_PID=$!

sleep 3

# Test connections
echo -e "\n${BLUE}🔍 Testing Local Connections${NC}"

# Test Django
if curl -s http://localhost:8000/api/v1/livestream/test-connection/ >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Django backend responding locally${NC}"
else
    echo -e "${RED}❌ Django backend not responding locally${NC}"
fi

# Test LiveKit
if curl -s http://localhost:7880/ >/dev/null 2>&1; then
    echo -e "${GREEN}✅ LiveKit server responding locally${NC}"
else
    echo -e "${YELLOW}⚠️ LiveKit connection test returned non-200 (normal)${NC}"
fi

echo -e "\n${GREEN}🎉 Multi-Device LiveKit Environment Ready!${NC}"

echo -e "\n${BLUE}📱 Device Configuration:${NC}"
echo -e "${YELLOW}Server Device (this machine - $MACHINE_IP):${NC}"
echo -e "  • LiveKit: ws://$MACHINE_IP:7880"
echo -e "  • Django API: http://$MACHINE_IP:8000"

echo -e "\n${YELLOW}Client Device (other Mac):${NC}"
echo -e "  • Update React app serverUrl to: ws://$MACHINE_IP:7880"
echo -e "  • Update Django API calls to: http://$MACHINE_IP:8000"

echo -e "\n${BLUE}🔧 Network Requirements:${NC}"
echo -e "  • Both Macs must be on same network (192.168.1.x)"
echo -e "  • Firewall must allow ports: 7880, 7881, 50000-60000"
echo -e "  • Test connectivity: ping $MACHINE_IP (from other Mac)"

echo -e "\n${BLUE}🧪 Test Token Generation:${NC}"
echo -e "${YELLOW}curl -X POST http://$MACHINE_IP:8000/api/v1/livestream/generate-token/ \\${NC}"
echo -e "${YELLOW}-H 'Content-Type: application/json' \\${NC}"
echo -e "${YELLOW}-d '{\"identity\": \"test\", \"room_name\": \"test-room\", \"role\": \"host\"}'${NC}"

echo -e "\n${BLUE}🚀 Next Steps:${NC}"
echo -e "  1. On the CLIENT Mac, update React app with server IP: $MACHINE_IP"
echo -e "  2. Start React app: npm run dev -- --host 0.0.0.0"
echo -e "  3. Test: One Mac broadcasts, other Mac views"

echo -e "\n${BLUE}📝 Logs:${NC}"
echo -e "  • LiveKit: tail -f livekit.log"
echo -e "  • Check for 'participant joined' messages when connecting"

echo -e "\n${RED}🛑 To Stop: ${YELLOW}kill $LIVEKIT_PID $DJANGO_PID${NC}"

# Store PIDs
echo "$LIVEKIT_PID" > livekit.pid
echo "$DJANGO_PID" > django.pid

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}🛑 Stopping services...${NC}"
    kill $LIVEKIT_PID $DJANGO_PID 2>/dev/null || true
    rm -f livekit.pid django.pid livekit.yaml 2>/dev/null || true
    echo -e "${GREEN}✅ Services stopped${NC}"
    exit 0
}

trap cleanup INT TERM

echo -e "\n${GREEN}💡 Multi-device environment ready! Configure the other Mac and test!${NC}"

# Keep running and show status
while true; do
    sleep 30
    
    if ! kill -0 $LIVEKIT_PID 2>/dev/null; then
        echo -e "${RED}❌ LiveKit server stopped${NC}"
        tail -10 livekit.log
        break
    fi
    
    if ! kill -0 $DJANGO_PID 2>/dev/null; then
        echo -e "${RED}❌ Django server stopped${NC}"
        break
    fi
    
    echo -e "${GREEN}💚 Services running on $MACHINE_IP (LiveKit: $LIVEKIT_PID, Django: $DJANGO_PID)${NC}"
done

cleanup