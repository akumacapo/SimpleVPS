#!/bin/bash
# SimpleVPS - Instalador con KEY BotGen (robusto para nc.traditional)
RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'
BLUE='\033[1;36m'; WHITE='\033[1;37m'; NC='\033[0m'

clear
echo -e "${BLUE}┌──────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│${NC}     ${YELLOW}SimpleVPS Manager - Instalador KEY${NC}     ${BLUE}│${NC}"
echo -e "${BLUE}└──────────────────────────────────────────────┘${NC}"
echo ""
[[ $EUID -ne 0 ]] && { echo -e "${RED}[!] Root requerido${NC}"; exit 1; }

ofus () {
	unset txtofus
	local number=$(expr length "$1") i
	for((i=1; i<$number+1; i++)); do
		txt[$i]=$(echo "$1" | cut -b $i)
		case ${txt[$i]} in
			".")txt[$i]="*";; "*")txt[$i]=".";;
			"1")txt[$i]="@";; "@")txt[$i]="1";;
			"2")txt[$i]="?";; "?")txt[$i]="2";;
			"4")txt[$i]="%";; "%")txt[$i]="4";;
			"-")txt[$i]="K";; "K")txt[$i]="-";;
		esac
		txtofus+="${txt[$i]}"
	done
	echo "$txtofus" | rev
}

# Descarga un archivo via BotGen nc (reintentos; nc solo 1 conexion)
bg_get() {
	local out="$1" url1="$2" url2="$3"
	local n=0
	while [[ $n -lt 8 ]]; do
		# curl suele manejar mejor respuestas raras de nc
		if command -v curl >/dev/null 2>&1; then
			if curl -sS -m 20 --http1.0 -o "$out" "$url1" 2>/dev/null && [[ -s "$out" ]]; then
				grep -qiE 'KEY INVALIDA|ERROR-KEY|FERRAMENTA KEY' "$out" 2>/dev/null && return 1
				return 0
			fi
			if [[ -n "$url2" ]] && curl -sS -m 20 --http1.0 -o "$out" "$url2" 2>/dev/null && [[ -s "$out" ]]; then
				grep -qiE 'KEY INVALIDA|ERROR-KEY|FERRAMENTA KEY' "$out" 2>/dev/null && return 1
				return 0
			fi
		fi
		wget -q -O "$out" --timeout=20 --no-http-keep-alive "$url1" 2>/dev/null && [[ -s "$out" ]] && return 0
		[[ -n "$url2" ]] && wget -q -O "$out" --timeout=20 --no-http-keep-alive "$url2" 2>/dev/null && [[ -s "$out" ]] && return 0
		# raw TCP fallback (sin HTTP client)
		if command -v nc >/dev/null 2>&1 || command -v nc.traditional >/dev/null 2>&1; then
			local NCBIN=$(command -v nc.traditional || command -v nc)
			local host port path
			host=$(echo "$url1" | sed -E 's|https?://([^/:]+).*|\1|')
			port=$(echo "$url1" | sed -E 's|https?://[^/:]+(:([0-9]+))?.*|\2|'); [[ -z "$port" ]] && port=80
			path=$(echo "$url1" | sed -E 's|https?://[^/]+||')
			printf 'GET %s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n' "$path" "$host" | \
				$NCBIN -w 15 "$host" "$port" 2>/dev/null | sed '1,/^\r$/d' > "$out"
			[[ -s "$out" ]] && ! grep -qiE 'KEY INVALIDA|ERROR-KEY' "$out" && return 0
		fi
		((n++))
		sleep 2
	done
	return 1
}

KEY="${1}"
[[ -z "$KEY" ]] && { echo -ne "${YELLOW}Ingresa tu KEY de BotGen: ${NC}"; read KEY; }
KEY=$(echo "$KEY" | tr -d '[:space:]')
[[ -z "$KEY" ]] && { echo -e "${RED}[!] KEY vacia${NC}"; exit 1; }

echo -e "${YELLOW}[*] Decodificando KEY...${NC}"
DECODE=$(ofus "$KEY")
IP=$(echo "$DECODE" | cut -d: -f1)
REST=$(echo "$DECODE" | cut -d: -f2-)
PORT=$(echo "$REST" | cut -d/ -f1)
KEYID=$(echo "$REST" | cut -d/ -f2)
LISTA=$(echo "$REST" | cut -d/ -f3)
[[ -z "$LISTA" ]] && LISTA="lista-arq"

echo -e "  Servidor: ${WHITE}${IP}:${PORT}${NC}"
echo -e "  Key ID:   ${WHITE}${KEYID}${NC}"

MI_IP=$(wget -qO- ipv4.icanhazip.com 2>/dev/null || curl -s --max-time 5 ipv4.icanhazip.com)
[[ -z "$MI_IP" ]] && MI_IP="0.0.0.0"

BASE="http://${IP}:${PORT}/${KEYID}"
TMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -p /root)
cd "$TMPDIR" || exit 1

echo -e "${YELLOW}[*] Descargando lista de archivos...${NC}"
if ! bg_get "$LISTA" "${BASE}/${LISTA}/${MI_IP}" "${BASE}/${LISTA}"; then
	echo -e "${RED}[!] No se obtuvo la lista. KEY invalida/usada o puerto cerrado.${NC}"
	rm -rf "$TMPDIR"; exit 1
fi
if grep -qiE 'INVALIDA|ERROR|FERRAMENTA|INSTALA' "$LISTA" 2>/dev/null; then
	echo -e "${RED}[!] Respuesta de error del servidor:${NC}"; head -5 "$LISTA"
	rm -rf "$TMPDIR"; exit 1
fi
echo -e "${GREEN}[✓] Lista obtenida${NC}"
echo -e "${YELLOW}[*] Descargando archivos (con pausa para nc)...${NC}"

ok=0
while read -r arq || [[ -n "$arq" ]]; do
	arq=$(echo "$arq" | tr -d '\r' | xargs)
	[[ -z "$arq" || "$arq" == "lista-arq" ]] && continue
	sleep 1.5
	if bg_get "$arq" "${BASE}/${arq}/${MI_IP}" "${BASE}/${arq}"; then
		echo -e "  ${GREEN}+${NC} $arq ($(wc -c < "$arq") bytes)"
		((ok++))
	else
		echo -e "  ${RED}x${NC} $arq (fallo)"
	fi
done < "$LISTA"

if [[ $ok -lt 1 ]]; then
	echo -e "${RED}[!] Ningun archivo descargado.${NC}"
	echo -e "${YELLOW}Prueba manual en el generador:${NC}"
	echo -e "  curl -v --http1.0 -o /tmp/t.sh http://127.0.0.1:${PORT}/${KEYID}/menu.sh"
	rm -rf "$TMPDIR"; exit 1
fi

DIR="/etc/SimpleVPS"
echo -e "${YELLOW}[*] Instalando en ${DIR}...${NC}"
mkdir -p ${DIR}/{bin,lib,db,tmp,backup}
cp -f menu.sh ${DIR}/menu.sh 2>/dev/null; chmod +x ${DIR}/menu.sh 2>/dev/null
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
for pkg in curl wget openssl; do command -v $pkg &>/dev/null || apt-get install -y $pkg &>/dev/null; done
[[ -f ${DIR}/bin/sysctl_bbr.sh ]] && bash ${DIR}/bin/sysctl_bbr.sh 2>/dev/null || true
cd /; rm -rf "$TMPDIR"
echo ""
echo -e "${GREEN}[✓] Instalacion completada${NC}"
echo -e "  Comandos: ${YELLOW}simplevps${NC} / ${YELLOW}svp${NC}"
echo ""
