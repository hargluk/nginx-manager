#!/bin/bash

# --- ЦВЕТА ---
if [ -t 1 ]; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    NC=$(tput sgr0)
else
    RED=''; GREEN=''; YELLOW=''; NC=''
fi

TARGET="/usr/local/bin/nginx-manager"

# ----------------------------------------
#  САМОУСТАНОВКА (если запущено не из TARGET)
# ----------------------------------------
if [[ "$0" != "$TARGET" && "$0" != *"/nginx-manager" ]]; then
    echo -e "${YELLOW}Этот скрипт может установить себя в $TARGET для удобного вызова.${NC}"
    read -p "Установить (скопировать) себя в $TARGET ? (y/n): " ans
    if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
        if [[ $EUID -ne 0 ]]; then
            echo -e "${RED}Для установки нужны права root. Запустите с sudo.${NC}"
            exit 1
        fi
        cp "$0" "$TARGET"
        chmod +x "$TARGET"
        echo -e "${GREEN}Скрипт установлен как $TARGET${NC}"
        echo -e "Теперь вы можете запускать его командой: ${YELLOW}sudo nginx-manager${NC}"
        exec "$TARGET"
    else
        echo -e "${YELLOW}Продолжаем без установки (будут ограничения).${NC}"
        echo -e "Рекомендуется установить для полноценной работы.\n"
    fi
fi

# ----------------------------------------
#  ОСНОВНАЯ ЧАСТЬ (требует root)
# ----------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Запускайте с sudo${NC}"
    exit 1
fi

# 1. Проверка и установка nginx
echo -e "${YELLOW}Проверка наличия nginx...${NC}"
if ! command -v nginx &> /dev/null; then
    echo -e "${YELLOW}Nginx не найден. Установить? (y/n)${NC}"
    read -p "> " install_nginx
    if [[ "$install_nginx" == "y" || "$install_nginx" == "Y" ]]; then
        apt update
        apt install -y nginx
        systemctl enable nginx
        systemctl start nginx
        echo -e "${GREEN}Nginx установлен и запущен.${NC}"
    else
        echo -e "${RED}Без nginx работа невозможна. Выход.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}Nginx уже установлен.${NC}"
fi

# 2. Создание необходимых папок и файла списка
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
touch /etc/nginx/.my_sites

NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
WEB_ROOT="/var/www"
LIST_FILE="/etc/nginx/.my_sites"

# ----------------------------------------
#  ФУНКЦИИ
# ----------------------------------------

init_list() {
    touch "$LIST_FILE"
}

check_packages() {
    echo "======================================"
    echo "     Выбор пакетов для установки"
    echo "======================================"

    local php_installed=0
    local mysql_installed=0
    local postgres_installed=0
    local sqlite_installed=0
    local certbot_installed=0

    command -v php &> /dev/null && php_installed=1
    command -v mysql &> /dev/null && mysql_installed=1
    command -v psql &> /dev/null && postgres_installed=1
    command -v sqlite3 &> /dev/null && sqlite_installed=1
    command -v certbot &> /dev/null && certbot_installed=1

    local packages=()
    local names=()
    local statuses=()

    packages+=("php")                         ; names+=("PHP (php-fpm, модули)")       ; statuses+=($php_installed)
    packages+=("mysql-server")                ; names+=("MySQL")                       ; statuses+=($mysql_installed)
    packages+=("postgresql")                  ; names+=("PostgreSQL")                  ; statuses+=($postgres_installed)
    packages+=("sqlite3")                     ; names+=("SQLite3")                     ; statuses+=($sqlite_installed)
    packages+=("certbot")                     ; names+=("Certbot + Nginx плагин")      ; statuses+=($certbot_installed)

    echo "Текущий статус:"
    for i in "${!packages[@]}"; do
        local status_text="${RED}не установлен${NC}"
        [[ ${statuses[$i]} -eq 1 ]] && status_text="${GREEN}установлен${NC}"
        echo "$((i+1)). ${names[$i]} : $status_text"
    done
    echo "0. Установить всё (только недостающее)"
    echo ""
    read -p "Введите номера через пробел для установки (например: 1 3 5) или 0: " choices

    if [[ "$choices" == "0" ]]; then
        local to_install=()
        for i in "${!packages[@]}"; do
            if [[ ${statuses[$i]} -eq 0 ]]; then
                to_install+=("${packages[$i]}")
            fi
        done
        if [[ ${#to_install[@]} -eq 0 ]]; then
            echo -e "${GREEN}Всё уже установлено.${NC}"
        else
            echo -e "${YELLOW}Устанавливаем: ${to_install[*]}${NC}"
            apt update
            for pkg in "${to_install[@]}"; do
                if [[ "$pkg" == "certbot" ]]; then
                    apt install -y certbot
                    apt install -y python3-certbot-nginx
                else
                    apt install -y "$pkg"
                fi
            done
            if [[ " ${to_install[*]} " =~ " php " ]]; then
                apt install -y php-fpm php-mysql php-pgsql php-sqlite3
            fi
            systemctl enable mysql 2>/dev/null; systemctl start mysql 2>/dev/null
            systemctl enable postgresql 2>/dev/null; systemctl start postgresql 2>/dev/null
            echo -e "${GREEN}Установка завершена.${NC}"
        fi
    else
        local selected=()
        for num in $choices; do
            if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#packages[@]} )); then
                local idx=$((num-1))
                if [[ ${statuses[$idx]} -eq 0 ]]; then
                    selected+=("${packages[$idx]}")
                else
                    echo -e "${YELLOW}${names[$idx]} уже установлен, пропускаем.${NC}"
                fi
            fi
        done
        if [[ ${#selected[@]} -eq 0 ]]; then
            echo -e "${YELLOW}Ничего не выбрано (или всё уже установлено).${NC}"
        else
            echo -e "${YELLOW}Устанавливаем: ${selected[*]}${NC}"
            apt update
            for pkg in "${selected[@]}"; do
                if [[ "$pkg" == "certbot" ]]; then
                    apt install -y certbot
                    apt install -y python3-certbot-nginx
                else
                    apt install -y "$pkg"
                fi
            done
            if [[ " ${selected[*]} " =~ " php " ]]; then
                apt install -y php-fpm php-mysql php-pgsql php-sqlite3
            fi
            [[ " ${selected[*]} " =~ " mysql-server " ]] && { systemctl enable mysql; systemctl start mysql; }
            [[ " ${selected[*]} " =~ " postgresql " ]] && { systemctl enable postgresql; systemctl start postgresql; }
            echo -e "${GREEN}Установка выбранных пакетов завершена.${NC}"
        fi
    fi
    read -p "Нажмите Enter..."
}

site_exists() {
    [[ -f "$NGINX_AVAILABLE/${1}.conf" ]]
}

add_to_list() {
    grep -qxF "$1" "$LIST_FILE" || echo "$1" >> "$LIST_FILE"
}

remove_from_list() {
    sed -i "/^$1$/d" "$LIST_FILE"
}

get_my_sites() {
    [[ -f "$LIST_FILE" ]] && cat "$LIST_FILE"
}

is_my_site() {
    grep -qxF "$1" "$LIST_FILE"
}

create_config() {
    local name="$1" domain="$2" root_path="$3" type="$4" port="$5"
    local config_file="$NGINX_AVAILABLE/${name}.conf"

    if site_exists "$name"; then
        echo -e "${RED}Сайт $name уже существует${NC}"
        return 1
    fi

    mkdir -p "$root_path"
    chown -R www-data:www-data "$root_path"
    if [[ ! -f "$root_path/index.html" && ! -f "$root_path/index.php" ]]; then
        echo "<h1>Welcome to $domain</h1><p>Created by nginx-manager</p>" > "$root_path/index.html"
    fi

    if [[ "$type" == "proxy" ]]; then
        cat > "$config_file" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;
    location / {
        proxy_pass http://127.0.0.1:$port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    else
        cat > "$config_file" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;
    root $root_path;
    index index.html index.htm index.php;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
    fi

    ln -sf "$config_file" "$NGINX_ENABLED/${name}.conf"
    add_to_list "$name"
    echo -e "${GREEN}Сайт $name создан и включён${NC}"
    return 0
}

delete_site() {
    local name="$1"
    if ! site_exists "$name"; then
        echo -e "${RED}Сайт $name не найден${NC}"
        return 1
    fi
    if ! is_my_site "$name"; then
        echo -e "${RED}Удалять можно только свои сайты.${NC}"
        return 1
    fi

    rm -f "$NGINX_ENABLED/${name}.conf" "$NGINX_AVAILABLE/${name}.conf"

    local root_path="$WEB_ROOT/$name"
    if [[ -d "$root_path" ]]; then
        read -p "Удалить папку $root_path? (y/n): " confirm
        [[ "$confirm" == "y" || "$confirm" == "Y" ]] && rm -rf "$root_path" && echo -e "${GREEN}Папка удалена${NC}" || echo -e "${YELLOW}Папка оставлена${NC}"
    fi

    remove_from_list "$name"
    echo -e "${GREEN}Сайт $name удалён${NC}"
}

list_my_sites() {
    local sites=($(get_my_sites))
    if [[ ${#sites[@]} -eq 0 ]]; then
        echo -e "${YELLOW}Нет созданных сайтов.${NC}"
        return
    fi
    echo -e "${GREEN}Мои сайты:${NC}"
    for name in "${sites[@]}"; do
        local status="выключен"
        [[ -L "$NGINX_ENABLED/${name}.conf" ]] && status="включён"
        local domain=$(grep -m1 'server_name' "$NGINX_AVAILABLE/${name}.conf" 2>/dev/null | awk '{print $2}' | sed 's/;//')
        echo "  $name ($domain) - $status"
    done
}

toggle_site() {
    local name="$1"
    local config="$NGINX_AVAILABLE/${name}.conf"
    local link="$NGINX_ENABLED/${name}.conf"
    if ! site_exists "$name"; then
        echo -e "${RED}Сайт $name не найден${NC}"
        return 1
    fi
    if [[ -L "$link" ]]; then
        rm -f "$link"
        echo -e "${GREEN}Сайт $name отключён${NC}"
    else
        ln -sf "$config" "$link"
        echo -e "${GREEN}Сайт $name включён${NC}"
    fi
}

reload_nginx() {
    echo -e "\n${YELLOW}Проверка конфигурации nginx...${NC}"
    if nginx -t 2>/dev/null; then
        systemctl reload nginx
        echo -e "${GREEN}Nginx перезагружен.${NC}"
    else
        echo -e "${RED}Ошибка в конфигурации. Nginx не перезагружен.${NC}"
        nginx -t
    fi
}

create_site_wizard() {
    echo -e "${GREEN}=== Создание сайта ===${NC}"
    read -p "Короткое имя (без пробелов): " name
    [[ -z "$name" ]] && echo -e "${RED}Имя не может быть пустым${NC}" && press_any_key && return
    site_exists "$name" && echo -e "${RED}Сайт с таким именем уже есть${NC}" && press_any_key && return

    read -p "Домен (example.com): " domain
    [[ -z "$domain" ]] && echo -e "${RED}Домен обязателен${NC}" && press_any_key && return

    echo "Тип: 1) Статика  2) Прокси"
    read -p "Выберите [1-2]: " type_choice
    local type="static" port=""
    if [[ "$type_choice" == "2" ]]; then
        type="proxy"
        read -p "Порт для прокси (например, 3000): " port
        [[ ! "$port" =~ ^[0-9]+$ ]] && echo -e "${RED}Порт должен быть числом${NC}" && press_any_key && return
    fi

    local root_path="$WEB_ROOT/$name"
    read -p "Корневая папка (по умолчанию $root_path): " custom_root
    [[ -n "$custom_root" ]] && root_path="$custom_root"

    create_config "$name" "$domain" "$root_path" "$type" "$port" && reload_nginx
    press_any_key
}

delete_site_wizard() {
    local sites=($(get_my_sites))
    [[ ${#sites[@]} -eq 0 ]] && echo -e "${YELLOW}Нет сайтов для удаления.${NC}" && press_any_key && return
    echo -e "${GREEN}Ваши сайты:${NC}"
    for i in "${!sites[@]}"; do echo "$((i+1))) ${sites[$i]}"; done
    read -p "Номер для удаления (0 - отмена): " num
    if [[ "$num" =~ ^[0-9]+$ ]] && (( num > 0 && num <= ${#sites[@]} )); then
        delete_site "${sites[$((num-1))]}" && reload_nginx
    else
        echo -e "${YELLOW}Отмена.${NC}"
    fi
    press_any_key
}

toggle_site_wizard() {
    local sites=($(get_my_sites))
    [[ ${#sites[@]} -eq 0 ]] && echo -e "${YELLOW}Нет сайтов.${NC}" && press_any_key && return
    echo -e "${GREEN}Ваши сайты:${NC}"
    for i in "${!sites[@]}"; do
        local status=""
        [[ -L "$NGINX_ENABLED/${sites[$i]}.conf" ]] && status=" (включён)" || status=" (выключен)"
        echo "$((i+1))) ${sites[$i]}$status"
    done
    read -p "Номер для переключения: " num
    if [[ "$num" =~ ^[0-9]+$ ]] && (( num > 0 && num <= ${#sites[@]} )); then
        toggle_site "${sites[$((num-1))]}" && reload_nginx
    else
        echo -e "${YELLOW}Отмена.${NC}"
    fi
    press_any_key
}

press_any_key() {
    read -p "Нажмите Enter..."
}

# ----------------------------------------
#  ГЛАВНОЕ МЕНЮ
# ----------------------------------------
menu() {
    clear
    echo "======================================"
    echo "      Управление сайтами nginx"
    echo "======================================"
    echo "1. Создать сайт"
    echo "2. Список моих сайтов"
    echo "3. Удалить сайт"
    echo "4. Вкл/Выкл сайт"
    echo "5. Перезагрузить nginx"
    echo "6. Установить пакеты (PHP, MySQL, PostgreSQL, SQLite3, Certbot)"
    echo "0. Выход"
    echo "======================================"
    read -p "Выберите пункт [1-7]: " choice
    case $choice in
        1) create_site_wizard ;;
        2) list_my_sites; press_any_key ;;
        3) delete_site_wizard ;;
        4) toggle_site_wizard ;;
        5) reload_nginx; press_any_key ;;
        6) check_packages ;;
        0) echo -e "${GREEN}До свидания!${NC}"; exit 0 ;;
        *) echo -e "${RED}Неверный выбор${NC}"; press_any_key ;;
    esac
}

# ----------------------------------------
#  ЗАПУСК
# ----------------------------------------
init_list
while true; do menu; done
