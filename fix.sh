#!/bin/bash

echo "🔍 macOS Network Diagnostics for LiveKit WebRTC"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get network info
echo -e "${BLUE}🌐 Network Information:${NC}"
MACHINE_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
echo "Machine IP: $MACHINE_IP"
echo "Network interfaces:"
ifconfig | grep -E "^[a-z]|inet " | grep -v "inet6"

# Check macOS firewall status
echo -e "\n${BLUE}🔥 Firewall Status:${NC}"
if /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate | grep -q "enabled"; then
    echo -e "${YELLOW}⚠️ macOS Application Firewall is ENABLED${NC}"
    echo "Firewall might be blocking connections"
    echo -e "${YELLOW}Suggested fix: Temporarily disable for testing${NC}"
    echo "  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off"
else
    echo -e "${GREEN}✅ macOS Application Firewall is disabled${NC}"
fi

# Check if processes are listening on required ports
echo -e "\n${BLUE}📡 Port Status:${NC}"
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        local pid=$(lsof -Pi :$port -sTCP:LISTEN -t)
        local process=$(ps -p $pid -o comm= 2>/dev/null)
        echo -e "${GREEN}✅ Port $port: LISTENING (PID: $pid, Process: $process)${NC}"
    else
        echo -e "${RED}❌ Port $port: NOT LISTENING${NC}"
    fi
}

check_port 7880
check_port 7881
check_port 8000

# Check UDP port range
echo -e "\n${BLUE}🎯 UDP Port Range Check:${NC}"
UDP_CHECK=$(lsof -i UDP | grep -E ":(5000[0-9]|50100)" | wc -l)
echo "UDP ports 50000-50100 in use: $UDP_CHECK"

# Network connectivity test function
test_connectivity() {
    echo -e "\n${BLUE}🔗 Basic Connectivity Tests:${NC}"
    
    # Test localhost
    if curl -s --max-time 3 http://localhost:7880/ >/dev/null 2>&1; then
        echo -e "${GREEN}✅ localhost:7880 reachable${NC}"
    else
        echo -e "${RED}❌ localhost:7880 not reachable${NC}"
    fi
    
    # Test network IP
    if curl -s --max-time 3 http://$MACHINE_IP:7880/ >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $MACHINE_IP:7880 reachable${NC}"
    else
        echo -e "${RED}❌ $MACHINE_IP:7880 not reachable${NC}"
    fi
    
    # Test Django
    if curl -s --max-time 3 http://localhost:8000/api/v1/livestream/test-connection/ >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Django API reachable${NC}"
    else
        echo -e "${RED}❌ Django API not reachable${NC}"
    fi
}

test_connectivity

# Create simplified LiveKit config for debugging
create_simple_config() {
    echo -e "\n${BLUE}📝 Creating simplified LiveKit config for debugging:${NC}"
    
    cat > livekit_simple.yaml << EOF
# Minimal LiveKit config for WebRTC debugging
port: 7880
bind_addresses: ["0.0.0.0"]

rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 50020  # Very small range for testing
  use_external_ip: false  # Try with internal first
  # No ICE servers for local testing
  
turn:
  enabled: false

keys:
  devkey: secret

room:
  empty_timeout: 300
  max_participants: 10

logging:
  level: debug
EOF

    echo "Created livekit_simple.yaml with minimal configuration"
}

# Function to restart LiveKit with simple config
restart_livekit_simple() {
    echo -e "\n${BLUE}🔄 Restarting LiveKit with simplified config:${NC}"
    
    # Stop existing LiveKit
    pkill -f livekit-server
    sleep 3
    
    # Start with simple config
    nohup livekit-server --config livekit_simple.yaml > livekit_simple.log 2>&1 &
    LIVEKIT_PID=$!
    echo "LiveKit PID: $LIVEKIT_PID"
    echo "$LIVEKIT_PID" > livekit_simple.pid
    
    sleep 5
    
    # Check if it started
    if lsof -Pi :7880 -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${GREEN}✅ LiveKit started with simple config${NC}"
        
        # Show logs
        echo -e "\n${BLUE}📋 Recent logs:${NC}"
        tail -10 livekit_simple.log
        
        return 0
    else
        echo -e "${RED}❌ LiveKit failed to start${NC}"
        cat livekit_simple.log
        return 1
    fi
}

# macOS specific network fixes
apply_macos_fixes() {
    echo -e "\n${BLUE}🔧 Applying macOS-specific fixes:${NC}"
    
    echo "1. Disabling macOS Application Firewall temporarily:"
    echo "   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off"
    
    echo -e "\n2. For permanent fix, add LiveKit to firewall whitelist:"
    echo "   System Preferences → Security & Privacy → Firewall → Firewall Options"
    echo "   Add livekit-server and allow incoming connections"
    
    echo -e "\n3. Check Network Location settings:"
    echo "   System Preferences → Network → Location → Automatic"
    
    echo -e "\n4. Reset network if needed:"
    echo "   sudo dscacheutil -flushcache"
    echo "   sudo killall -HUP mDNSResponder"
}

# WebRTC specific debugging
webrtc_debug_tips() {
    echo -e "\n${BLUE}🎥 WebRTC Debugging Tips:${NC}"
    echo "1. Open Chrome/Firefox Developer Tools"
    echo "2. Go to chrome://webrtc-internals/ (Chrome) or about:webrtc (Firefox)"
    echo "3. Look for ICE candidate generation"
    echo "4. Check for 'host' candidates with your local IP"
    echo "5. Monitor connection state changes"
    
    echo -e "\n${YELLOW}Expected ICE candidates:${NC}"
    echo "  - host: $MACHINE_IP:50000-50020 (local network)"
    echo "  - srflx: external IP (if behind NAT)"
    
    echo -e "\n${YELLOW}React App Updates for testing:${NC}"
    echo "  1. Use serverUrl: 'ws://localhost:7880' for same-machine testing"
    echo "  2. Use serverUrl: 'ws://$MACHINE_IP:7880' for cross-machine testing"
    echo "  3. Check browser console for detailed WebRTC logs"
}

# Main menu
show_menu() {
    echo -e "\n${BLUE}🛠️ Choose an action:${NC}"
    echo "1. Create simple LiveKit config and restart"
    echo "2. Test network connectivity"
    echo "3. Apply macOS firewall fixes"
    echo "4. Show WebRTC debugging tips"
    echo "5. Run full diagnostic"
    echo "6. Exit"
    echo ""
    read -p "Enter choice (1-6): " choice
    
    case $choice in
        1)
            create_simple_config
            restart_livekit_simple
            ;;
        2)
            test_connectivity
            ;;
        3)
            apply_macos_fixes
            ;;
        4)
            webrtc_debug_tips
            ;;
        5)
            create_simple_config
            restart_livekit_simple
            test_connectivity
            apply_macos_fixes
            webrtc_debug_tips
            ;;
        6)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice"
            show_menu
            ;;
    esac
}

# Run initial diagnostics
echo -e "\n${BLUE}🎯 Quick Fix Recommendations:${NC}"
echo "1. Try disabling macOS firewall temporarily"
echo "2. Restart LiveKit with simplified config"
echo "3. Test with localhost URLs first"
echo "4. Check WebRTC internals in browser"

show_menu