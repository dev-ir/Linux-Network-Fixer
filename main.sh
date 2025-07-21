#!/bin/bash

# Linux Network Fixer
# File: /usr/local/bin/linux-net

clear

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# Config directory
CONFIG_DIR="/etc/linux-network-fixer"

# Read DNS list from config
dns_list=()
while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  dns_list+=("$line")
done < "$CONFIG_DIR/dns_list.dns"

# Read mirror list from config
mirrors=()
while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  mirrors+=("$line")
done < "$CONFIG_DIR/ubuntu_sources.mirror"

# Read test domains from config
test_domains=()
while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  test_domains+=("$line")
done < "$CONFIG_DIR/test_domains.list"

# Detect OS
get_os() {
  if [ -e /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  elif [ -e /etc/redhat-release ]; then
    echo "rhel"
  elif [ -e /etc/debian_version ]; then
    echo "debian"
  else
    echo "unknown"
  fi
}

# Get current DNS and mirror for display
get_status_inline() {
  current_dns=$(grep -m1 nameserver /etc/resolv.conf | awk '{print $2}')
  if [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
    current_mirror=$(grep -m1 -o 'http[s]\?://[^ ]*' /etc/apt/sources.list 2>/dev/null)
  else
    current_mirror="N/A"
  fi
}

# Set best DNS
set_best_dns() {
  echo -e "${CYAN}Testing DNS Servers for domain resolution...${NC}"
  echo "--------------------------------------------------------"
  cp /etc/resolv.conf /etc/resolv.conf.bak

  for dns in "${dns_list[@]}"; do
    echo -e "\nTesting ${CYAN}$dns${NC}..."
    echo "nameserver $dns" > /etc/resolv.conf
    all_ok=true
    for domain in "${test_domains[@]}"; do
      if curl -s --head --connect-timeout 5 http://$domain | grep -q "200 OK"; then
        echo -e "  ✅ ${GREEN}$domain reachable${NC}"
      else
        echo -e "  ❌ ${RED}$domain unreachable${NC}"
        all_ok=false
      fi
    done
    if $all_ok; then
      echo -e "\n${GREEN}✅ Using DNS $dns${NC}"
      return
    fi
  done

  echo -e "${RED}❌ No valid DNS found. Restoring...${NC}"
  mv /etc/resolv.conf.bak /etc/resolv.conf
}

# Set fastest mirror for Ubuntu/Debian
set_fastest_mirror() {
  if [[ "$os" != "ubuntu" && "$os" != "debian" ]]; then
    echo -e "${RED}Mirror selection only supported on Ubuntu/Debian.${NC}"
    read -p "Press Enter to return..."
    return
  fi

  echo -e "${CYAN}Testing Mirrors...${NC}"
  best_mirror=""
  best_speed=0
  for mirror in "${mirrors[@]}"; do
    speed=$(wget --timeout=5 --tries=1 -O /dev/null "$mirror" 2>&1 | grep -o '[0-9.]* [KM]B/s' | tail -1)
    if [[ -z $speed ]]; then
      echo -e "${CYAN}$mirror${WHITE} | ${RED}Failed${NC}"
      continue
    fi
    if [[ $speed == *K* ]]; then
      kb=$(echo $speed | sed 's/ KB\/s//')
    else
      mb=$(echo $speed | sed 's/ MB\/s//')
      kb=$(echo "scale=2; $mb * 1024" | bc)
    fi
    echo -e "${CYAN}$mirror${WHITE} | ${GREEN}${kb} KB/s${NC}"
    if (( $(echo "$kb > $best_speed" | bc -l) )); then
      best_speed=$kb
      best_mirror=$mirror
    fi
  done

  if [[ -n $best_mirror ]]; then
    echo -e "\n${GREEN}Using fastest mirror: $best_mirror${NC}"
    version=$(lsb_release -sr | cut -d '.' -f 1)
    if [[ "$version" -ge 24 ]]; then
      sudo sed -i "s|http[s]\?://[^ ]*|$best_mirror|g" /etc/apt/sources.list.d/ubuntu.sources
    else
      sudo sed -i "s|http[s]\?://[^ ]*|$best_mirror|g" /etc/apt/sources.list
    fi
    sudo apt-get update
  else
    echo -e "${RED}No suitable mirror found.${NC}"
  fi
  read -p "Press Enter to return..."
}

# Main menu loop
while true; do
  os=$(get_os)
  get_status_inline
  clear
  echo -e "${BLUE}╔════════════════════════════════════════════════════╗"
  echo -e "║               Linux Network Optimizer              ║"
  echo -e "╠════════════════════════════════════════════════════╣"
  echo -e "║ 🌐 DNS:    ${CYAN}$current_dns${NC}"
  echo -e "║ 🔗 Mirror: ${CYAN}$current_mirror${NC}"
  echo -e "╠════════════════════════════════════════════════════╣"
  echo -e "║ ${CYAN}[1]${WHITE} 🔁 Check & Set Fastest Mirror (Ubuntu/Debian)   ║"
  echo -e "║ ${CYAN}[2]${WHITE} 🌐 Check & Set Best DNS (All Distros)           ║"
  echo -e "║ ${CYAN}[0]${RED} ❌ Exit                                         ${WHITE}║"
  echo -e "╚════════════════════════════════════════════════════╝"
  echo
  read -p "Select an option: " choice
  case $choice in
    1) set_fastest_mirror ;;
    2) set_best_dns ;;
    0) exit 0 ;;
    *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
  esac
done
