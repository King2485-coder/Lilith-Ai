#!/bin/bash
################################################################################
# Lilith Private LTE Network - Deployment Script
# 
# This script deploys the complete 2-node Private LTE network with:
# - Open5GS Core Network (AMF, SMF, UPF, UDM, UDR, HSS, etc.)
# - srsRAN 4G - 2 eNodeB nodes
# - Lilith SMS MITM Interception System
# - Lilith Voice Redirect (SIP/VoIP)
# - eSIM Profiles with QR codes
#
# Usage: ./deploy.sh [start|stop|status|logs]
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="lilith-lte"
COMPOSE_FILE="docker-compose.yml"
LOG_DIR="./logs"

# Functions
print_header() {
    echo -e "${BLUE}"
    echo "============================================================"
    echo "  Lilith Private LTE Network - Deployment Manager"
    echo "============================================================"
    echo -e "${NC}"
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    print_status "Checking dependencies..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose."
        exit 1
    fi
    
    # Check if ports are available
    print_status "Checking port availability..."
    
    local required_ports=(27017 38412 5060 5000 8080)
    for port in "${required_ports[@]}"; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            print_warning "Port $port is already in use"
        fi
    done
    
    print_status "All dependencies satisfied"
}

init_directories() {
    print_status "Initializing directories..."
    
    mkdir -p $LOG_DIR
    mkdir -p logs/open5gs
    mkdir -p logs/srsran
    mkdir -p logs/lilith
    
    print_status "Directories initialized"
}

init_subscribers() {
    print_status "Registering subscribers in HSS/UDM..."
    
    # Initialize subscribers using Python script
    python3 open5gs/init_subscribers.py
    
    print_status "Subscribers registered:"
    print_status "  - User A: IMSI 001010000000001, MSISDN 111"
    print_status "  - User B: IMSI 001010000000002, MSISDN 222"
}

start_network() {
    print_header
    
    check_dependencies
    init_directories
    
    print_status "Starting Lilith Private LTE Network..."
    
    # Pull required images
    print_status "Pulling Docker images..."
    docker-compose -f $COMPOSE_FILE pull --ignore-pull-failures 2>/dev/null || true
    
    # Build custom images
    print_status "Building custom images..."
    docker-compose -f $COMPOSE_FILE build
    
    # Start core network first
    print_status "Starting Open5GS Core Network..."
    docker-compose -f $COMPOSE_FILE up -d mongodb nrf
    sleep 5
    
    # Start AMF and other core components
    print_status "Starting AMF, SMF, UPF, UDM, UDR..."
    docker-compose -f $COMPOSE_FILE up -d amf smf upf udm udr ausf pcf nssf bsf
    sleep 5
    
    # Start HSS
    print_status "Starting HSS..."
    docker-compose -f $COMPOSE_FILE up -d hss
    sleep 3
    
    # Start eNodeB nodes
    print_status "Starting srsRAN eNodeB Nodes 1 & 2..."
    docker-compose -f $COMPOSE_FILE up -d enb-node1 enb-node2
    sleep 5
    
    # Start UE simulators
    print_status "Starting UE Simulators..."
    docker-compose -f $COMPOSE_FILE up -d ue-usera ue-userb
    sleep 3
    
    # Start Lilith services
    print_status "Starting Lilith MITM and Voice services..."
    docker-compose -f $COMPOSE_FILE up -d lilith-mitm lilith-sip
    
    # Initialize subscribers
    init_subscribers
    
    print_status "Network deployment complete!"
    show_status
}

stop_network() {
    print_status "Stopping Lilith Private LTE Network..."
    docker-compose -f $COMPOSE_FILE down
    print_status "Network stopped"
}

show_status() {
    print_header
    
    echo -e "${BLUE}Container Status:${NC}"
    docker-compose -f $COMPOSE_FILE ps 2>/dev/null || echo "No containers running"
    
    echo ""
    echo -e "${BLUE}Network Services:${NC}"
    echo "  Open5GS Core:    http://localhost:7777 (NRF)"
    echo "  Lilith MITM API: http://localhost:8080"
    echo "  SIP Server:      localhost:5060 (UDP/TCP)"
    echo "  MongoDB:         localhost:27017"
    
    echo ""
    echo -e "${BLUE}Subscribers:${NC}"
    echo "  User A: IMSI 001010000000001, MSISDN 111"
    echo "  User B: IMSI 001010000000002, MSISDN 222"
    
    echo ""
    echo -e "${BLUE}eSIM Profiles:${NC}"
    echo "  User A QR: ./esim/qr_codes/lilith_esim_user_a.png"
    echo "  User B QR: ./esim/qr_codes/lilith_esim_user_b.png"
    
    echo ""
    echo -e "${BLUE}Voice Service:${NC}"
    echo "  Dial 0 to reach Operator Lilith"
}

show_logs() {
    local service=$1
    
    if [ -z "$service" ]; then
        echo "Available services: mongodb, amf, smf, upf, enb-node1, enb-node2, lilith-mitm, lilith-sip"
        read -p "Enter service name: " service
    fi
    
    docker-compose -f $COMPOSE_FILE logs -f $service
}

show_help() {
    print_header
    echo "Usage: ./deploy.sh [command]"
    echo ""
    echo "Commands:"
    echo "  start       - Deploy the complete network"
    echo "  stop        - Stop all services"
    echo "  restart     - Restart the network"
    echo "  status      - Show network status"
    echo "  logs [svc]  - Show logs for a service"
    echo "  test-sms    - Send test SMS between users"
    echo "  test-voice  - Test voice redirect to Lilith"
    echo "  help        - Show this help message"
}

test_sms() {
    print_status "Testing SMS interception..."
    
    curl -X POST http://localhost:8080/api/simulate \
        -H "Content-Type: application/json" \
        -d '{
            "source": "111",
            "destination": "222",
            "content": "Hello User B, I am focused on the Red State today. Critical operations require immediate attention."
        }' 2>/dev/null | python3 -m json.tool || echo "Lilith MITM API not available"
}

test_voice() {
    print_status "Testing voice redirect..."
    print_status "To test: Dial 0 from User A or User B"
    print_status "SIP server should respond with Lilith's greeting"
    
    # Check if SIP server is running
    if nc -z localhost 5060 2>/dev/null; then
        print_status "SIP server is accessible"
    else
        print_warning "SIP server may not be ready yet"
    fi
}

# Main
case "${1:-help}" in
    start)
        start_network
        ;;
    stop)
        stop_network
        ;;
    restart)
        stop_network
        sleep 3
        start_network
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs $2
        ;;
    test-sms)
        test_sms
        ;;
    test-voice)
        test_voice
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
