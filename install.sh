#!/bin/bash
# SimpleVPS - Instalador con KEY de BotGen
# Uso: bash install.sh
#      bash install.sh "TU_KEY_AQUI"

RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'
BLUE='\033[1;36m'; WHITE='\033[1;37m'; NC='\033[0m'

clear
echo -e "${BLUE}┌──────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│${NC}     ${YELLOW}SimpleVPS Manager - Instalador KEY${NC}     ${BLUE}│${NC}"
echo -e "${BLUE}└──────────────────────────────────────────────┘${NC}"
echo ""

[[ $EUID -ne 0 ]] && { echo -e "${RED}[!] Ejecutar como root${NC}"; exit 1; }

# ─── Ofuscación BotGen (simétrica) ───
ofus () {
	unset txtofus
	local number=$(expr length "$1")
	local i txt
	for((i=1; i<$number+1; i++)); do
		txt[$i]=$(echo "$1" | cut -b $i)
		case ${txt[$i]} in
			".")txt[$i]="*";;
			"*")txt[$i]=".";;
			"1")txt[$i]="@";;
			"@")txt[$i]="1";;
			"2")txt[$i]="?";;
			"?")txt[$i]="2";;
			"4")txt[$i]="%";;
			"%")txt[$i]="4";;
			"-")txt[$i]="K";;
			"K")txt[$i]="-";;
		esac
		txtofus+="${txt[$i]}"
	done
	echo "$txtofus" | rev
}

# ─── Pedir / recibir KEY ───
KEY="${1}"
if [[ -z "$KEY" ]]; then
	echo -ne "${YELLOW}Ingresa tu KEY de BotGen: ${NC}"
	read KEY
fi
KEY=$(echo "$KEY" | tr -d '[:space:]')
[[ -z "$KEY" ]] && { echo -e "${RED}[!] KEY vacia${NC}"; exit 1; }

echo -e "${YELLOW}[*] Decodificando KEY...${NC}"
DECODE=$(ofus "$KEY")
# Formato esperado: IP:PUERTO/IDKEY/lista-arq
IP=$(echo "$DECODE" | cut -d: -f1)
REST=$(echo "$DECODE" | cut -d: -f2-)
PORT=$(echo "$REST" | cut -d/ -f1)
KEYID=$(echo "$REST" | cut -d/ -f2)
LISTA=$(echo "$REST" | cut -d/ -f3)
[[ -z "$LISTA" ]] && LISTA="lista-arq"

echo -e "  Servidor: ${WHITE}${IP}:${PORT}${NC}"
echo -e "  Key ID:   ${WHITE}${KEYID}${NC}"

# IP del cliente (BotGen la exige en el path)
MI_IP=$(wget -qO- ipv4.icanhazip.com 2>/dev/null || curl -s --max-time 5 ipv4.icanhazip.com)
[[ -z "$MI_IP" ]] && MI_IP="0.0.0.0"

BASE="http://${IP}:${PORT}/${KEYID}"
TMPDIR=$(mktemp -d)
cd "$TMPDIR" || exit 1

echo -e "${YELLOW}[*] Descargando lista de archivos...${NC}"
# Request: /KEYID/lista-arq/IP_CLIENTE
if ! wget -q -O "$LISTA" --timeout=15 "${BASE}/${LISTA}/${MI_IP}" 2>/dev/null; then
	# fallback sin IP al final
	wget -q -O "$LISTA" --timeout=15 "${BASE}/${LISTA}" 2>/dev/null || true
fi

if [[ ! -s "$LISTA" ]] || grep -qiE 'INVALIDA|ERROR|FERRAMENTA|INSTALA' "$LISTA" 2>/dev/null; then
	echo -e "${RED}[!] KEY invalida, expirada o ya usada${NC}"
	echo -e "${RED}    Respuesta del servidor:${NC}"
	head -5 "$LISTA" 2>/dev/null
	rm -rf "$TMPDIR"
	exit 1
fi

echo -e "${GREEN}[✓] Lista obtenida${NC}"
echo -e "${YELLOW}[*] Descargando archivos del script...${NC}"

ok=0
while read -r arq || [[ -n "$arq" ]]; do
	arq=$(echo "$arq" | tr -d '\r' | xargs)
	[[ -z "$arq" ]] && continue
	[[ "$arq" == "lista-arq" ]] && continue
	if wget -q -O "$arq" --timeout=20 "${BASE}/${arq}/${MI_IP}" 2>/dev/null || \
	   wget -q -O "$arq" --timeout=20 "${BASE}/${arq}" 2>/dev/null; then
		echo -e "  ${GREEN}+${NC} $arq"
		((ok++))
	else
		echo -e "  ${RED}x${NC} $arq (fallo)"
	fi
done < "$LISTA"

if [[ $ok -lt 1 ]]; then
	echo -e "${RED}[!] No se descargo ningun archivo. Revisa puerto 8888 y la KEY.${NC}"
	rm -rf "$TMPDIR"
	exit 1
fi

# ─── Instalar ───
DIR="/etc/SimpleVPS"
echo -e "${YELLOW}[*] Instalando en ${DIR}...${NC}"
mkdir -p ${DIR}/{bin,lib,db,tmp,backup}

cp -f menu.sh ${DIR}/menu.sh 2>/dev/null
chmod +x ${DIR}/menu.sh 2>/dev/null

# binarios / scripts auxiliares
for f in limitador.sh autokill.sh cleaner.sh monitor.sh payloads.sh sysctl_bbr.sh tg_login_watch.sh \
         inst_hysteria.sh inst_xray.sh inst_slowdns.sh inst_wsproxy.sh inst_nginx.sh; do
	[[ -f $f ]] && cp -f $f ${DIR}/bin/ && chmod +x ${DIR}/bin/$f
done
[[ -f funcoes.sh ]] && cp -f funcoes.sh ${DIR}/lib/ && chmod +x ${DIR}/lib/funcoes.sh

ln -sf ${DIR}/menu.sh /usr/bin/simplevps
ln -sf ${DIR}/menu.sh /usr/bin/svp

touch ${DIR}/db/users.db ${DIR}/db/xray_users.db
[[ ! -f ${DIR}/db/banner.txt ]] && echo "SimpleVPS - Acceso autorizado" > ${DIR}/db/banner.txt
echo -e "VERSION=5.0\nPORT_SSH=22" > ${DIR}/db/config

# deps basicas
for pkg in curl wget openssl; do
	command -v $pkg &>/dev/null || apt-get install -y $pkg &>/dev/null
done
[[ -f ${DIR}/bin/sysctl_bbr.sh ]] && bash ${DIR}/bin/sysctl_bbr.sh 2>/dev/null || true

cd /
rm -rf "$TMPDIR"

echo ""
echo -e "${GREEN}[✓] Instalacion completada con KEY${NC}"
echo -e "${BLUE}────────────────────────────────────────${NC}"
echo -e "  Comandos: ${YELLOW}simplevps${NC}  /  ${YELLOW}svp${NC}"
echo -e "${BLUE}────────────────────────────────────────${NC}"
echo ""
