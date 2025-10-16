#!/bin/bash

# RealityEZPZ Auto-Installer
# Поддержка выбора HTTP-портов и SNI

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Проверка прав
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Запустите скрипт с правами root!${NC}"
    exit 1
fi

# Списки параметров
STANDARD_PORTS=("443" "80" "8080" "8880" "2052" "2082" "2086" "2095")
RECOMMENDED_SNI=(
    "www.google.com"
    "www.cloudflare.com"
    "github.com"
    "www.microsoft.com"
    "apple.com"
    "www.amazon.com"
    "openai.com"
    "discord.com"
    "stackoverflow.com"
    "www.reddit.com"
    "chat.openai.com"
    "www.yahoo.com"
    "www.bing.com"
    "github.com"
    "gitlab.com"
)

# Функция выбора порта
select_port() {
    echo -e "\n${YELLOW}╔══════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║           Выбор порта сервера         ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════╝${NC}"
    echo -e "${CYAN}Рекомендуемые порты для лучшей совместимости:${NC}"
    
    for i in "${!STANDARD_PORTS[@]}"; do
        case ${STANDARD_PORTS[$i]} in
            "443")  desc="HTTPS (рекомендуется)" ;;
            "80")   desc="HTTP" ;;
            "8080") desc="Альтернативный HTTP" ;;
            "8880") desc="Альтернативный HTTP" ;;
            "2052") desc="cPanel" ;;
            "2082") desc="cPanel SSL" ;;
            "2086") desc="WHM" ;;
            "2095") desc="Webmail" ;;
            *)      desc="Стандартный HTTP" ;;
        esac
        echo "$((i+1))) Порт ${GREEN}${STANDARD_PORTS[$i]}${NC} - $desc"
    done
    echo "9) Другой порт"
    
    while true; do
        read -p "Выберите порт [1-9]: " port_choice
        
        case $port_choice in
            [1-8])
                SERVER_PORT="${STANDARD_PORTS[$((port_choice-1))]}"
                break
                ;;
            9)
                read -p "Введите номер порта: " custom_port
                if [[ $custom_port =~ ^[0-9]+$ ]] && [ $custom_port -gt 0 ] && [ $custom_port -lt 65536 ]; then
                    SERVER_PORT=$custom_port
                    break
                else
                    echo -e "${RED}Ошибка: Введите корректный номер порта (1-65535)${NC}"
                fi
                ;;
            *)
                echo -e "${RED}Неверный выбор. Попробуйте снова.${NC}"
                ;;
        esac
    done
}

# Функция выбора SNI
select_sni() {
    echo -e "\n${YELLOW}╔══════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║        Выбор SNI (поддельный домен)   ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════╝${NC}"
    echo -e "${CYAN}Рекомендуемые SNI для лучшей маскировки:${NC}"
    
    for i in "${!RECOMMENDED_SNI[@]}"; do
        echo "$((i+1))) ${GREEN}${RECOMMENDED_SNI[$i]}${NC}"
    done
    echo "16) Другой SNI"
    
    while true; do
        read -p "Выберите SNI [1-16]: " sni_choice
        
        if [ "$sni_choice" -ge 1 ] && [ "$sni_choice" -le 15 ]; then
            SNI_DOMAIN="${RECOMMENDED_SNI[$((sni_choice-1))]}"
            break
        elif [ "$sni_choice" -eq 16 ]; then
            read -p "Введите свой SNI домен: " custom_sni
            if [[ -n "$custom_sni" ]]; then
                SNI_DOMAIN=$custom_sni
                break
            else
                echo -e "${RED}Ошибка: SNI не может быть пустым${NC}"
            fi
        else
            echo -e "${RED}Неверный выбор. Попробуйте снова.${NC}"
        fi
    done
}

# Проверка занятости порта
check_port() {
    if command -v netstat >/dev/null 2>&1; then
        if netstat -tuln | grep -q ":$1 "; then
            echo -e "${RED}⚠️  Порт $1 занят!${NC}"
            return 1
        fi
    elif command -v ss >/dev/null 2>&1; then
        if ss -tuln | grep -q ":$1 "; then
            echo -e "${RED}⚠️  Порт $1 занят!${NC}"
            return 1
        fi
    fi
    return 0
}

# Установка зависимостей
install_dependencies() {
    echo -e "\n${YELLOW}Установка зависимостей...${NC}"
    
    if command -v apt >/dev/null 2>&1; then
        apt update
        apt install -y curl ufw jq net-tools qrencode
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl jq net-tools qrencode
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y curl jq net-tools qrencode
    else
        echo -e "${YELLOW}Не удалось определить менеджер пакетов. Продолжаем...${NC}"
    fi
}

# Настройка фаервола
configure_firewall() {
    echo -e "\n${YELLOW}Настройка фаервола...${NC}"
    
    if command -v ufw >/dev/null 2>&1; then
        ufw allow ssh >/dev/null 2>&1
        ufw allow $SERVER_PORT/tcp >/dev/null 2>&1
        echo -e "${GREEN}✓ Разрешен порт $SERVER_PORT в UFW${NC}"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=$SERVER_PORT/tcp >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
        echo -e "${GREEN}✓ Разрешен порт $SERVER_PORT в firewalld${NC}"
    elif command -v iptables >/dev/null 2>&1; then
        iptables -A INPUT -p tcp --dport $SERVER_PORT -j ACCEPT >/dev/null 2>&1
        echo -e "${GREEN}✓ Разрешен порт $SERVER_PORT в iptables${NC}"
    else
        echo -e "${YELLOW}⚠️  Фаервол не найден, убедитесь что порт $SERVER_PORT открыт${NC}"
    fi
}

# Установка Xray
install_xray() {
    echo -e "\n${YELLOW}Установка Xray...${NC}"
    
    if [ ! -f "/usr/local/bin/xray" ]; then
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    else
        echo -e "${GREEN}✓ Xray уже установлен${NC}"
    fi
}

# Генерация ключей
generate_keys() {
    echo -e "\n${YELLOW}Генерация ключей...${NC}"
    
    mkdir -p $CONFIG_DIR
    /usr/local/bin/xray x25519 > $CONFIG_DIR/key.txt
    PRIVATE_KEY=$(grep "Private key:" $CONFIG_DIR/key.txt | awk '{print $3}')
    PUBLIC_KEY=$(grep "Public key:" $CONFIG_DIR/key.txt | awk '{print $3}')
    SHORT_ID=$(openssl rand -hex 8)
    UUID=$(cat /proc/sys/kernel/random/uuid)
    
    echo -e "${GREEN}✓ Ключи сгенерированы${NC}"
}

# Создание конфигурации сервера
create_config() {
    echo -e "\n${YELLOW}Создание конфигурации сервера...${NC}"
    
    cat > /usr/local/etc/xray/config.json <<EOF
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": $SERVER_PORT,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$UUID",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "dest": "$SNI_DOMAIN:443",
                    "xver": 0,
                    "serverNames": ["$SNI_DOMAIN"],
                    "privateKey": "$PRIVATE_KEY",
                    "maxTimeDiff": 60000,
                    "shortIds": ["$SHORT_ID"]
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": ["http", "tls"]
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
}
EOF
    
    echo -e "${GREEN}✓ Конфигурация создана${NC}"
}

# Запуск службы
enable_service() {
    echo -e "\n${YELLOW}Запуск службы Xray...${NC}"
    
    systemctl enable xray >/dev/null 2>&1
    systemctl restart xray
    
    sleep 2
    
    if systemctl is-active --quiet xray; then
        echo -e "${GREEN}✓ Xray успешно запущен${NC}"
    else
        echo -e "${RED}✗ Ошибка запуска Xray${NC}"
        journalctl -u xray -n 10 --no-pager
        exit 1
    fi
}

# Генерация клиентских конфигов
generate_client_configs() {
    echo -e "\n${YELLOW}Генерация клиентских конфигураций...${NC}"
    
    SERVER_HOST=$(curl -s4 ifconfig.me)
    
    # VLESS URL для импорта
    CLIENT_URL="vless://$UUID@$SERVER_HOST:$SERVER_PORT?type=tcp&security=reality&sni=$SNI_DOMAIN&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&flow=xtls-rprx-vision#RealityEZPZ"
    
    # Сохранение URL
    echo "$CLIENT_URL" > $CONFIG_DIR/client-url.txt
    
    # Детальный конфиг
    cat > $CONFIG_DIR/client-info.txt <<EOF
╔══════════════════════════════════════╗
║         Reality EZPZ Config         ║
╚══════════════════════════════════════╝

📍 Сервер: $SERVER_HOST
🔌 Порт: $SERVER_PORT
🆔 UUID: $UUID
🔑 Public Key: $PUBLIC_KEY
🎯 Short ID: $SHORT_ID
🌐 SNI: $SNI_DOMAIN
🚀 Flow: xtls-rprx-vision

📋 URL для импорта:
$CLIENT_URL

💡 Рекомендуемые клиенты:
• V2RayN (Windows)
• v2rayNG (Android) 
• Shadowrocket (iOS)
• Qv2ray (Linux/macOS)

EOF

    echo -e "${GREEN}✓ Конфигурации сохранены в $CONFIG_DIR/${NC}"
}

# Показать результат
show_result() {
    echo -e "\n${GREEN}"
    echo "╔══════════════════════════════════════╗"
    echo "║         УСТАНОВКА ЗАВЕРШЕНА!        ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
    
    cat $CONFIG_DIR/client-info.txt
    
    # Показать QR-код если установлен qrencode
    if command -v qrencode >/dev/null 2>&1; then
        echo -e "\n${CYAN}QR-код для быстрого импорта:${NC}"
        qrencode -t UTF8 < $CONFIG_DIR/client-url.txt
    fi
    
    echo -e "\n${YELLOW}📁 Конфиги сохранены в: $CONFIG_DIR/${NC}"
    echo -e "${YELLOW}🔧 Проверить статус: systemctl status xray${NC}"
    echo -e "${YELLOW}📋 Показать конфиг: cat $CONFIG_DIR/client-info.txt${NC}"
}

# Основная функция
main() {
    clear
    echo -e "${BLUE}"
    cat << "EOF"
╔══════════════════════════════════════╗
║           Reality EZPZ              ║
║    Автонастройка Xray + Reality     ║
║     с выбором портов и SNI          ║
╚══════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    # Настройки
    CONFIG_DIR="/etc/reality"
    
    # Получение IP сервера
    SERVER_HOST=$(curl -s4 ifconfig.me)
    if [ -z "$SERVER_HOST" ]; then
        SERVER_HOST=$(curl -s6 ifconfig.me)
    fi
    
    echo -e "${CYAN}📍 Ваш IP: $SERVER_HOST${NC}"
    
    # Выбор параметров
    select_port
    
    # Проверка порта
    if ! check_port $SERVER_PORT; then
        echo -e "${YELLOW}Выберите другой порт:${NC}"
        select_port
    fi
    
    select_sni
    
    # Подтверждение
    echo -e "\n${YELLOW}╔══════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║           Подтверждение               ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════╝${NC}"
    echo -e "🔌 Порт: ${GREEN}$SERVER_PORT${NC}"
    echo -e "🌐 SNI: ${GREEN}$SNI_DOMAIN${NC}"
    echo -e "📍 Сервер: ${GREEN}$SERVER_HOST${NC}"
    echo ""
    
    read -p "Продолжить установку? [y/N]: " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${RED}Установка отменена${NC}"
        exit 0
    fi
    
    # Установка
    install_dependencies
    configure_firewall
    install_xray
    generate_keys
    create_config
    enable_service
    generate_client_configs
    show_result
}

# Запуск основной функции
main