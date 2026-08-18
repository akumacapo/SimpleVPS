#!/bin/bash
# ADMRufu - Instalador con KEY de BotGen
# Uso: bash install.sh
#      bash install.sh "TU_KEY"

RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'
BLUE='\033[1;36m'; WHITE='\033[1;37m'; NC='\033[0m'

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}   ADMRufu - Instalador con KEY BotGen${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

[[ $EUID -ne 0 ]] && { echo -e "${RED}[!] Ejecutar como root${NC}"; exit 1; }

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

bg_get() {
	local out="$1" url1="$2" url2="$3"
	local n=0
	while [[ $n -lt 10 ]]; do
		if command -v curl >/dev/null 2>&1; then
			if curl -sS -m 25 --http1.0 -o "$out" "$url1" 2>/dev/null && [[ -s "$out" ]]; then
				grep -qiE 'KEY INVALIDA|ERROR-KEY|FERRAMENTA KEY|KEY DE INSTALA' "$out" 2>/dev/null && { ((n++)); sleep 2; continue; }
				return 0
			fi
			if [[ -n "$url2" ]] && curl -sS -m 25 --http1.0 -o "$out" "$url2" 2>/dev/null && [[ -s "$out" ]]; then
				grep -qiE 'KEY INVALIDA|ERROR-KEY|FERRAMENTA KEY|KEY DE INSTALA' "$out" 2>/dev/null && { ((n++)); sleep 2; continue; }
				return 0
			fi
		fi
		wget -q -O "$out" --timeout=25 --no-http-keep-alive "$url1" 2>/dev/null && [[ -s "$out" ]] && \
			! grep -qiE 'KEY INVALIDA|ERROR-KEY|KEY DE INSTALA' "$out" 2>/dev/null && return 0
		[[ -n "$url2" ]] && wget -q -O "$out" --timeout=25 --no-http-keep-alive "$url2" 2>/dev/null && [[ -s "$out" ]] && \
			! grep -qiE 'KEY INVALIDA|ERROR-KEY|KEY DE INSTALA' "$out" 2>/dev/null && return 0
		((n++)); sleep 2
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
echo -e "  Tu IP:    ${WHITE}${MI_IP}${NC}"

BASE="http://${IP}:${PORT}/${KEYID}"
TMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -p /root)
cd "$TMPDIR" || exit 1

echo -e "${YELLOW}[*] Descargando lista...${NC}"
if ! bg_get "$LISTA" "${BASE}/${LISTA}/${MI_IP}" "${BASE}/${LISTA}"; then
	echo -e "${RED}[!] No se obtuvo la lista. KEY invalida/usada o puerto 8888 cerrado.${NC}"
	rm -rf "$TMPDIR"; exit 1
fi
if grep -qiE 'INVALIDA|ERROR|FERRAMENTA|INSTALA' "$LISTA" 2>/dev/null; then
	echo -e "${RED}[!] Error del servidor:${NC}"; cat "$LISTA"
	rm -rf "$TMPDIR"; exit 1
fi
echo -e "${GREEN}[✓] Lista OK${NC}"

echo -e "${YELLOW}[*] Descargando archivos ADMRufu (pausa entre cada uno)...${NC}"
ok=0
fail=0
while read -r arq || [[ -n "$arq" ]]; do
	arq=$(echo "$arq" | tr -d '\r' | xargs)
	[[ -z "$arq" || "$arq" == "lista-arq" ]] && continue
	sleep 1.5
	if bg_get "$arq" "${BASE}/${arq}/${MI_IP}" "${BASE}/${arq}"; then
		echo -e "  ${GREEN}+${NC} $arq"
		((ok++))
	else
		echo -e "  ${RED}x${NC} $arq"
		((fail++))
	fi
done < "$LISTA"

if [[ $ok -lt 3 ]]; then
	echo -e "${RED}[!] Demasiados fallos ($ok ok, $fail fail). Abortando.${NC}"
	rm -rf "$TMPDIR"; exit 1
fi

# ─── Instalar estructura ADMRufu ───
echo -e "${YELLOW}[*] Instalando ADMRufu...${NC}"
ADMRufu="/etc/ADMRufu"
mkdir -p ${ADMRufu}/{install,tmp,bin,sbin}
mkdir -p /etc/http-shell

# Binario / comando principal
if [[ -f ADMRufu ]]; then
	cp -f ADMRufu /usr/bin/ADMRufu
	chmod +x /usr/bin/ADMRufu
	ln -sf /usr/bin/ADMRufu /usr/bin/menu
	ln -sf /usr/bin/ADMRufu /usr/bin/adm
fi

# Scripts al directorio del panel
for f in bashrc menu menu_inst.sh tool_extras.sh chekup.sh limitador.sh \
         userSSH userHWID userTOKEN userV2ray.sh v2ray.sh squid.sh slowdns.sh \
         openvpn.sh sockspy.sh ws-cdn.sh budp.sh cert.sh domain.sh tcpbbr.sh \
         swapfile.sh PDirect.py PGet.py POpen.py PPriv.py PPub.py WS-Proxy.js install.sh; do
	[[ -f $f ]] && cp -f "$f" ${ADMRufu}/ && chmod +x ${ADMRufu}/$f 2>/dev/null
done

# Si existe menu como ejecutable principal alternativo
[[ -f menu && ! -f /usr/bin/ADMRufu ]] && cp -f menu /usr/bin/ADMRufu && chmod +x /usr/bin/ADMRufu

# install.sh de referencia
[[ -f install.sh ]] && cp -f install.sh ${ADMRufu}/install.sh && chmod +x ${ADMRufu}/install.sh

# Dependencias basicas
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq &>/dev/null
for pkg in curl wget jq openssl python3 net-tools; do
	command -v $pkg &>/dev/null || apt-get install -y $pkg &>/dev/null
done

# Mensaje / version
echo "BotGen-$(date +%Y%m%d)" > ${ADMRufu}/vercion 2>/dev/null
[[ -f ${ADMRufu}/bashrc ]] && cp -f ${ADMRufu}/bashrc /etc/ADMRufu/bashrc

# Aviso en bashrc del root (opcional)
grep -q ADMRufu /root/.bashrc 2>/dev/null || echo 'alias menu="/usr/bin/menu"' >> /root/.bashrc

cd /
rm -rf "$TMPDIR"

echo ""
echo -e "${GREEN}[✓] ADMRufu instalado con KEY BotGen${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Comandos: ${YELLOW}menu${NC}  /  ${YELLOW}adm${NC}  /  ${YELLOW}ADMRufu${NC}"
echo -e "  Archivos: ${WHITE}${ADMRufu}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Nota:${NC} Si el panel pide licencia propia de Rufu,"
echo -e "      es del autor; la KEY de BotGen solo entrego los archivos."
echo ""
