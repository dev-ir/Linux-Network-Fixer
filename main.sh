#!/bin/bash

# File: /usr/local/bin/linux-net
# Make sure to chmod +x this file and link it for global use

clear

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# Read DNS list from .dns file
dns_list=()
while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  dns_list+=("$line")
done < "dns_list.dns"

# Read mirror list from .mirror file
mirrors=()
while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  mirrors+=("$line")
done < "ubuntu_sources.mirror"

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

# Show current mirror and DNS
show_status() {
  echo -e "${BLUE}Current DNS:${NC}"
  grep nameserver /etc/resolv.conf | awk '{print "  - "$2}'

  echo -e "\n${BLUE}Current Mirror:${NC}"
  if [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
    grep -m1 -o 'http[s]\?://[^ ]*' /etc/apt/sources.list 2>/dev/null
  else
    echo "Not applicable."
  fi
  echo
  read -p "Press Enter to continue..."
}

# Set best DNS
set_best_dns() {
  echo -e "${CYAN}Testing DNS Servers for domain resolution...${NC}"
  echo "--------------------------------------------------------"
  cp /etc/resolv.conf /etc/resolv.conf.bak

  case "$os" in
    almalinux|centos|rhel)
      test_domains=("repo.cpanel.net" "yum.almalinux.org" "archive.mariadb.org" "securedownloads.cpanel.net")
      ;;
    ubuntu|debian)
      test_domains=("archive.ubuntu.com" "security.ubuntu.com")
      ;;
    *)
      test_domains=("google.com" "cloudflare.com")
      ;;
  esac

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
    speed=$(wget --timeout=5 --tries=1 -O /dev/null $mirror 2>&1 | grep -o '[0-9.]* [KM]B/s' | tail -1)
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
  clear
  echo -e "${BLUE}╔═════════════════════════════════════════════╗"
  echo -e "║               Linux Network Fixer                  ║"
  echo -e "╠════════════════════════════════════════════════════╣"
  echo -e "║ ${CYAN}[1]${WHITE} 🔁 Check & Set Fastest Mirror   ║"
  echo -e "║ ${CYAN}[2]${WHITE} 🌐 Check & Set Best DNS         ║"
  echo -e "║ ${CYAN}[3]${WHITE} 📊 Show Current DNS & Mirror    ║"
  echo -e "║ ${CYAN}[0]${RED} ❌ Exit                   ${WHITE}║"
  echo -e "╚════════════════════════════════════════════════════╝"
  echo
  read -p "Select an option: " choice
  case $choice in
    1) set_fastest_mirror ;;
    2) set_best_dns ;;
    3) show_status ;;
    0) exit 0 ;;
    *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
  esac
done