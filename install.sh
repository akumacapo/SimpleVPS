#!/bin/bash
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; BLUE='\033[1;36m'; WHITE='\033[1;37m'; NC='\033[0m'
clear
echo -e "${BLUE}┌──────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│${NC}     ${YELLOW}SimpleVPS Manager v5.0 LTS${NC}              ${BLUE}│${NC}"
echo -e "${BLUE}│${NC}     Panel de Control VPS                     ${BLUE}│${NC}"
echo -e "${BLUE}└──────────────────────────────────────────────┘${NC}"
echo ""
[[ $EUID -ne 0 ]] && { echo -e "${RED}[!] Root requerido${NC}"; exit 1; }

DIR="/etc/SimpleVPS"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p ${DIR}/{bin,lib,db,tmp,backup}

echo -e "${YELLOW}[*] Instalando...${NC}"
cp -f ${SCRIPT_DIR}/menu.sh ${DIR}/menu.sh
cp -f ${SCRIPT_DIR}/bin/* ${DIR}/bin/ 2>/dev/null
cp -f ${SCRIPT_DIR}/lib/* ${DIR}/lib/ 2>/dev/null
chmod +x ${DIR}/menu.sh ${DIR}/bin/* ${DIR}/lib/* 2>/dev/null
ln -sf ${DIR}/menu.sh /usr/bin/simplevps
ln -sf ${DIR}/menu.sh /usr/bin/svp

touch ${DIR}/db/users.db ${DIR}/db/xray_users.db
echo "SimpleVPS - Acceso autorizado" > ${DIR}/db/banner.txt
echo -e "VERSION=5.0\nPORT_SSH=22" > ${DIR}/db/config

apt-get update -qq &>/dev/null
for pkg in curl wget openssl unzip python3; do
  command -v $pkg &>/dev/null || apt-get install -y $pkg &>/dev/null
done

# Optimizacion de red al instalar
bash ${DIR}/bin/sysctl_bbr.sh 2>/dev/null || true

echo ""
echo -e "${GREEN}[✓] Instalacion completada${NC}"
echo -e "  Comandos: ${YELLOW}simplevps${NC} / ${YELLOW}svp${NC}"
echo -e "  ${WHITE}Zero-Lag · Auto-Kill · Telegram · Nginx · BBR · Payloads${NC}"
echo ""
