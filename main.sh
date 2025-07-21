#!/bin/bash

# Linux Network Fixer Main Script

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m'

CONFIG_DIR="/etc/linux-network-fixer"

# Utility Functions
get_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  else
    echo "unknown"
  fi
}

get_status_inline() {
  current_dns=$(grep -m1 nameserver /etc/resolv.conf | awk '{print $2}')
  os=$(get_os)

  if [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
    if [[ -f /etc/apt/sources.list ]]; then
      current_mirror=$(grep -m1 '^deb ' /etc/apt/sources.list | awk '{print $2}' | awk -F/ '{print $3}')
    elif [[ -f /etc/apt/sources.list.d/ubuntu.sources ]]; then
      current_mirror=$(grep -m1 -o 'http[s]\?://[^ ]*' /etc/apt/sources.list.d/ubuntu.sources | awk -F/ '{print $3}')
    fi
  elif [[ "$os" == "almalinux" || "$os" == "centos" || "$os" == "rhel" ]]; then
    current_mirror=$(dnf repolist -v 2>/dev/null | grep '^Repo-baseurl' | awk '{print $2}' | sed -E 's|http[s]?://([^/]+)/.*|\1|' | head -n1)
  else
    current_mirror="Unknown"
  fi
}

restore_defaults() {
  echo -e "${YELLOW}Restoring default DNS and mirror sources...${NC}"
  echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null

  os=$(get_os)
  if [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
    sudo cp "$CONFIG_DIR/default_sources.list" /etc/apt/sources.list
    sudo apt-get update
  elif [[ "$os" == "almalinux" || "$os" == "centos" || "$os" == "rhel" ]]; then
    sudo rm -f /etc/yum.repos.d/*.repo
    sudo cp "$CONFIG_DIR/default.repo.bak" /etc/yum.repos.d/default.repo
    sudo dnf clean all
    sudo dnf makecache
  fi
  echo -e "${GREEN}Defaults restored.${NC}"
  read -p "Press Enter to return..."
}

measure_speed() {
  local url=$1
  local result=$(timeout 5 wget --timeout=4 --tries=1 -O /dev/null "$url" 2>&1 | grep -o '[0-9.]* [KM]B/s' | tail -1)

  if [[ -z "$result" ]]; then
    echo -1
  else
    if [[ $result == *K* ]]; then
      echo $(echo $result | sed 's/ KB\/s//')
    elif [[ $result == *M* ]]; then
      echo $(echo "scale=2; $(echo $result | sed 's/ MB\/s//') * 1024" | bc)
    fi
  fi
}

test_dns() {
  echo -e "${BLUE}Testing DNS servers...${NC}"
  dns_list=( $(cat "$CONFIG_DIR/dns_list.dns" 2>/dev/null) )
  test_domains=( $(cat "$CONFIG_DIR/test_domains.list" 2>/dev/null) )
  valid_dns=()

  for dns in "${dns_list[@]}"; do
    echo -ne "Testing $dns... "
    success=0
    for domain in "${test_domains[@]}"; do
      timeout 2 dig @$dns $domain +short &>/dev/null && ((success++))
    done
    if (( success >= 2 )); then
      echo -e "${GREEN}OK${NC}"
      valid_dns+=("$dns")
    else
      echo -e "${RED}Failed${NC}"
    fi
  done

  if [ ${#valid_dns[@]} -eq 0 ]; then
    echo -e "${RED}No valid DNS found.${NC}"
  else
    echo -e "${GREEN}✔ Valid DNS: ${valid_dns[*]}${NC}"
    echo "nameserver ${valid_dns[0]}" | sudo tee /etc/resolv.conf > /dev/null
  fi
  read -p "Press Enter to return..."
}

select_mirror() {
  echo -e "${BLUE}Testing Mirrors...${NC}"
  os=$(get_os)

  if [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
    mirrors=( $(cat "$CONFIG_DIR/ubuntu_sources.mirror" 2>/dev/null) )
    best_mirror=""
    best_speed=0

    for mirror in "${mirrors[@]}"; do
      speed=$(measure_speed "$mirror")
      if [[ "$speed" == -1 ]]; then
        echo -e "$mirror | ${RED}Failed${NC}"
      else
        echo -e "$mirror | ${GREEN}${speed} KB/s${NC}"
        if (( $(echo "$speed > $best_speed" | bc -l) )); then
          best_speed=$speed
          best_mirror=$mirror
        fi
      fi
    done

    if [ -n "$best_mirror" ]; then
      echo -e "Using fastest mirror: $best_mirror"
      sudo sed -i "s|http[s]\?://[^ ]*ubuntu[^ ]*|$best_mirror|g" /etc/apt/sources.list
      sudo apt-get update
    else
      echo -e "${RED}No suitable mirror found.${NC}"
    fi
  elif [[ "$os" == "almalinux" || "$os" == "centos" || "$os" == "rhel" ]]; then
    echo -e "${BLUE}Setting mirrorlist for AlmaLinux/CentOS...${NC}"

    if [[ -f /etc/yum.repos.d/MariaDB1011.repo ]]; then
      sudo sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/MariaDB1011.repo
    fi

    arch=$(uname -m)
    releasever=$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release))

    sudo tee /etc/yum.repos.d/almalinux-base.repo > /dev/null <<EOF
[baseos]
name=AlmaLinux-\$releasever - BaseOS
mirrorlist=https://mirrors.almalinux.org/mirrorlist?repo=BaseOS&arch=$arch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux

[appstream]
name=AlmaLinux-\$releasever - AppStream
mirrorlist=https://mirrors.almalinux.org/mirrorlist?repo=AppStream&arch=$arch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux
EOF

    sudo dnf clean all
    sudo dnf makecache

    echo -e "${GREEN}✅ Mirrorlist updated for AlmaLinux/CentOS.${NC}"
  else
    echo -e "${RED}Mirror selection not supported on this OS.${NC}"
  fi
  read -p "Press Enter to return..."
}

main_menu() {
  while true; do
    clear
    get_status_inline
    echo -e "${CYAN}╔══════════════════════════════════════╗"
    echo -e "║   Linux Network Optimizer            ║"
    echo -e "╠══════════════════════════════════════╣"
    echo -e "║ 🌐 DNS:    ${YELLOW}${current_dns}${NC}"
    echo -e "║ 🔗 Mirror: ${YELLOW}${current_mirror}${NC}"
    echo -e "╠══════════════════════════════════════╣"
    echo -e "║ [1] 📥 Check & Set Fastest Mirror     "
    echo -e "║ [2] 🌐 Check & Set Best DNS          "
    echo -e "║ [3] 🔥 Uninstall Linux Network Fixer "
    echo -e "║ [4] ♻️  Restore Defaults (DNS+Mirror)"
    echo -e "║ [0] ❌ Exit                           "
    echo -e "╚══════════════════════════════════════╝"
    read -p "Select an option: " opt

    case $opt in
      1) select_mirror;;
      2) test_dns;;
      3) sudo rm -rf /opt/linux-network-fixer /etc/linux-network-fixer /usr/local/bin/linux-net; echo "Uninstalled."; exit;;
      4) restore_defaults;;
      0) exit;;
      *) echo "Invalid option"; sleep 1;;
    esac
  done
}

main_menu
