#!/bin/bash

echo "🌐 Using HTTP LiveKit with Chrome Security Bypass"

MACHINE_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

echo "This approach uses HTTP LiveKit + Chrome flags to bypass security"
echo "WSS URL in React: ws://$MACHINE_IP:7880 (not wss://)"
echo ""
echo "Chrome command:"
echo "/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \\"
echo "  --allow-running-insecure-content \\"
echo "  --disable-web-security \\"
echo "  --ignore-certificate-errors \\"
echo "  --unsafely-treat-insecure-origin-as-secure=\"https://$MACHINE_IP:3000\" \\"
echo "  https://$MACHINE_IP:3000"
