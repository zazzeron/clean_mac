#!/bin/bash

# Cores para formatação no terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Emojis para mais clareza
INFO="ℹ️"
CHECK="✅"
WARNING="⚠️"
BROOM="🧹"
TRASH="🗑️"
CLEANING="🧼"
CLOUD="☁️"
HOURGLASS="⌛"
PACKAGE="📦"
DOCUMENT="📄"
FOLDER="📂"
FIRED="🔥"

echo -e "${BROOM} ${BLUE}Iniciando limpeza segura no macOS...${RESET}"

# Inicializando contador total
total_freed=0

# Função para calcular espaço usado (em KB)
get_size() {
    du -sk "$1" 2>/dev/null | awk '{print $1}'
}

# Função para limpar diretório com contagem
clean_and_count() {
    local path="$1"
    local description="$2"

    echo -e "${INFO} ${YELLOW}Limpando: ${description}...${RESET}"

    if [ -d "$path" ]; then
        size_before=$(get_size "$path")
        sudo rm -rf "$path"/* 2>/dev/null
        total_freed=$((total_freed + size_before))
        echo -e "${CHECK} ${GREEN}Limpeza concluída: ${description}${RESET}"
    else
        echo -e "${WARNING} ${RED}Erro: O diretório ${path} não existe ou não pode ser acessado.${RESET}"
    fi
}

# Função para limpar cache do usuário ignorando pastas protegidas
clean_cache_user() {
    echo -e "${CLEANING} ${CYAN}Limpando cache do usuário (ignorando protegidos)...${RESET}"
    cache_dir="$HOME/Library/Caches"

    # Lista de pastas protegidas
    protected=(
        "CloudKit"
        "FamilyCircle"
        "com.apple.Safari"
        "com.apple.WebKit"
        "com.apple.AppStore"
        "com.apple.cloudphotod"
        "com.apple.Spotlight"
        "com.apple.ScreenTimeAgent"
    )

    for item in "$cache_dir"/*; do
        base=$(basename "$item")
        skip=0
        for protected_name in "${protected[@]}"; do
            if [[ "$base" == "$protected_name" ]]; then
                echo -e "${WARNING} ${YELLOW}Ignorado (protegido): ${base}${RESET}"
                skip=1
                break
            fi
        done

        if [[ $skip -eq 0 ]]; then
            size_before=$(get_size "$item")
            rm -rf "$item"
            total_freed=$((total_freed + size_before))
            echo -e "${CHECK} ${GREEN}Limpado: ${item}${RESET}"
        fi
    done
}

# 🗑️ Lixeiras (com proteção)
echo -e "${TRASH} Limpando lixeiras (onde permitido)...${RESET}"

trash_paths=(
    "$HOME/.Trash"
    /Users/*/.Trash
    /Volumes/*/.Trashes
)

for trash in "${trash_paths[@]}"; do
    if [ -d "$trash" ]; then
        echo -e "${TRASH} Tentando limpar: ${trash}"
        sudo find "$trash" -type f -exec rm -f {} \; 2>/dev/null
        sudo find "$trash" -type d -empty -delete 2>/dev/null
        echo -e "${CHECK} ${GREEN}Lixeira limpa: ${trash}${RESET}"
    else
        echo -e "${WARNING} ${RED}Erro: A lixeira ${trash} não pôde ser acessada ou não existe.${RESET}"
    fi
done

echo -e "${WARNING} Algumas lixeiras podem não ser esvaziadas devido à proteção do sistema (SIP)."

# 🔥 Limpeza principal
clean_cache_user
clean_and_count "/Library/Caches" "Cache do sistema"
clean_and_count "$HOME/Library/Logs" "Logs do usuário"
clean_and_count "/private/var/log" "Logs do sistema"
clean_and_count "/private/var/folders" "Arquivos temporários"
clean_and_count "/Library/Updates" "Atualizações do sistema"
clean_and_count "$HOME/Library/Containers" "Containers de apps"
clean_and_count "$HOME/Library/Application Support/CrashReporter" "Crash reports"
clean_and_count "$HOME/Library/Saved Application State" "Saved app states"

# ☁️ Limpeza do iCloud Drive local
icloud_trash="$HOME/Library/Mobile Documents/com~apple~CloudDocs/.Trash"
if [ -d "$icloud_trash" ]; then
    clean_and_count "$icloud_trash" "Lixeira do iCloud Drive"
else
    echo -e "${WARNING} ${YELLOW}Lixeira do iCloud Drive não encontrada ou não acessível.${RESET}"
fi

# ✅ Resultado final
echo -e "${CHECK} ----------------------------------------"
freed_mb=$((total_freed / 1024))
freed_gb=$(awk "BEGIN { printf \"%.2f\", $freed_mb / 1024 }")
echo -e "${CHECK} Limpeza concluída com sucesso!"
echo -e "${GREEN}🧼 Espaço total liberado: ${freed_mb} MB (~${freed_gb} GB)${RESET}"

