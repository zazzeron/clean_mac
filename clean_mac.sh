#!/bin/bash

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Emojis
INFO="ℹ️ "
CHECK="✅ "
WARNING="⚠️ "
BROOM="🧹 "
TRASH="🗑️ "
CLEANING="🧼 "
CLOUD="☁️ "
HOURGLASS="⌛ "
FIRED="🔥 "

# Variáveis
simulate=false
verbose=true
total_freed=0
log_file="cleaning_log.txt"

# Listas
ignored_directories=()
not_found_directories=()
successfully_cleaned=()

# Barra de progresso fake
progress_bar() {
    local delay=0.1
    local spinstr='|/-\'
    echo -n " "
    for i in $(seq 1 10); do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "\n\n"
}

# Verificação de root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Erro: Este script precisa ser executado com sudo.${RESET}"
    exit 1
fi

# 📋 Introdução
echo -e "${BLUE}Bem-vindo ao Assistente de Limpeza do macOS 🍏${RESET}"
echo -e "${CYAN}Este utilitário ajuda você a liberar espaço com segurança.${RESET}"

# Simulação
echo -e "\n${INFO} Deseja simular a limpeza (sem apagar nada)?"
select sim_option in "Sim (Recomendado)" "Não (Executar de verdade)"; do
    case $REPLY in
        1) simulate=true; break ;;
        2) simulate=false; break ;;
        *) echo "Opção inválida." ;;
    esac
done

# Verbosidade
echo -e "\n${INFO} Deseja ver detalhes durante a limpeza?"
select verb_option in "Sim (ver tudo)" "Não (modo silencioso)"; do
    case $REPLY in
        1) verbose=true; break ;;
        2) verbose=false; break ;;
        *) echo "Opção inválida." ;;
    esac
done

# Confirmação
echo -e "\n${INFO} Resumo da operação:"
echo -e "${TRASH} Modo: $([[ $simulate == true ]] && echo 'Simulação' || echo 'Real')"
echo -e "${DOCUMENT} Detalhamento: $([[ $verbose == true ]] && echo 'Ligado' || echo 'Desligado')"

read -p $'\n❗ Tem certeza que deseja continuar? (s/N): ' confirm
if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
    echo -e "${WARNING} Operação cancelada.${RESET}"
    exit 0
fi

echo -e "\n${HOURGLASS} Iniciando limpeza..."
progress_bar

# 📦 Funções principais
get_size() {
    du -sk "$1" 2>/dev/null | awk '{print $1}'
}

check_directory_exists() {
    [ -d "$1" ]
}

clean_and_count() {
    local path="$1"
    local description="$2"

    if ! check_directory_exists "$path"; then
        not_found_directories+=("$description → $path")
        return
    fi

    echo -e "\n${INFO} Limpando: $description"
    size_before=$(get_size "$path")

    if [ "$simulate" = false ]; then
        sudo rm -rf "$path"/* 2>/dev/null
    else
        echo -e "${INFO} [SIMULAÇÃO] Removeria arquivos de: $path"
    fi

    total_freed=$((total_freed + size_before))
    successfully_cleaned+=("$description (${size_before} KB)")
    [ "$verbose" = true ] && echo -e "${CHECK} ${GREEN}$description limpo com sucesso${RESET}"
}

clean_trash() {
    local trash_paths=("$HOME/.Trash" /Users/*/.Trash /Volumes/*/.Trashes)
    echo -e "${BROOM} ${CYAN}Iniciando limpeza das lixeiras...${RESET}"
    echo -e "${CYAN}--------------------------------------${RESET}"

    for trash in "${trash_paths[@]}"; do
        if ! check_directory_exists "$trash"; then
            not_found_directories+=("Lixeira → $trash")
            continue
        fi

        if [ "$simulate" = false ]; then
            sudo find "$trash" -type f -delete 2>/dev/null
            sudo find "$trash" -type d -empty -delete 2>/dev/null
        else
            echo -e "${INFO} [SIMULAÇÃO] Esvaziaria: $trash"
        fi

        successfully_cleaned+=("Lixeira: $trash")
        [ "$verbose" = true ] && echo -e "${CHECK} Lixeira limpa: $trash"
        [ "$verbose" = true ] && echo ""
    done
}

clean_cache_user() {
    local cache_dir="$HOME/Library/Caches"
    local protected=( "CloudKit" "FamilyCircle" "com.apple.Safari" "com.apple.WebKit" "com.apple.AppStore" )

    echo -e "${CLEANING} ${CYAN}Limpando cache do usuário...${RESET}"
    if ! check_directory_exists "$cache_dir"; then
        not_found_directories+=("Cache do usuário → $cache_dir")
        return
    fi

    for item in "$cache_dir"/*; do
        base=$(basename "$item")
        if printf '%s\n' "${protected[@]}" | grep -q "^$base$"; then
            ignored_directories+=("$base → $item")
            continue
        fi

        size_before=$(get_size "$item")
        if [ "$simulate" = false ]; then
            rm -rf "$item" 2>rm_error.log
            if grep -q "Operation not permitted" rm_error.log; then
                ignored_directories+=("$base → $item")
                rm -f rm_error.log
                continue
            fi
            rm -f rm_error.log
        else
            echo -e "${INFO} [SIMULAÇÃO] Removeria: $item"
        fi

        total_freed=$((total_freed + size_before))
        successfully_cleaned+=("Cache do usuário: $base (${size_before} KB)")
        [ "$verbose" = true ] && echo -e "${CHECK} Limpado: $item"
    done
}

# 🚀 Execução
clean_trash
clean_cache_user

clean_and_count "/Library/Caches" "Cache do sistema"
clean_and_count "$HOME/Library/Logs" "Logs do usuário"
clean_and_count "/private/var/log" "Logs do sistema"
clean_and_count "/private/var/folders" "Arquivos temporários"
clean_and_count "/Library/Updates" "Atualizações do sistema"
clean_and_count "$HOME/Library/Containers" "Containers de apps"
clean_and_count "$HOME/Library/Application Support/CrashReporter" "Crash reports"
clean_and_count "$HOME/Library/Saved Application State" "Saved app states"

icloud_trash="$HOME/Library/Mobile Documents/com~apple~CloudDocs/.Trash"
check_directory_exists "$icloud_trash" && clean_and_count "$icloud_trash" "Lixeira do iCloud"

# ✅ Resumo final
echo -e "\n${CHECK} ---------- RESUMO DA LIMPEZA ----------"

if [ ${#successfully_cleaned[@]} -gt 0 ]; then
    echo -e "\n${CLEANING} ${GREEN}Pastas limpas com sucesso:${RESET}"
    for dir in "${successfully_cleaned[@]}"; do
        echo -e "  ${CHECK} $dir"
    done
fi

if [ ${#ignored_directories[@]} -gt 0 ]; then
    echo -e "\n${WARNING} ${YELLOW}Pastas protegidas (não apagadas):${RESET}"
    for dir in "${ignored_directories[@]}"; do
        echo -e "  ${WARNING} $dir"
    done
fi

if [ ${#not_found_directories[@]} -gt 0 ]; then
    echo -e "\n${TRASH} ${RED}Pastas não encontradas ou inacessíveis:${RESET}"
    for dir in "${not_found_directories[@]}"; do
        echo -e "  ${TRASH} $dir"
    done
fi

freed_mb=$((total_freed / 1024))
freed_gb=$(awk "BEGIN { printf \"%.2f\", $freed_mb / 1024 }")
echo -e "\n${CHECK} Total de espaço liberado: ${GREEN}${freed_mb} MB (~${freed_gb} GB)${RESET}"

# Perguntar ao usuário se deseja salvar o log
echo -e "\n${INFO} Deseja salvar um log desta operação? (s/N)"
read -p "Digite sua resposta: " save_log
if [[ "$save_log" =~ ^[Ss]$ ]]; then
    log_file="cleaning_log_$(date +'%Y-%m-%d_%H-%M-%S').txt"
    echo -e "\n${INFO} Salvando log em: $log_file"
    echo -e "Resumo da Limpeza - $(date)" > "$log_file"
    echo -e "\nEspaço total liberado: ${freed_mb} MB (~${freed_gb} GB)" >> "$log_file"
    for dir in "${successfully_cleaned[@]}"; do
        echo -e "$dir" >> "$log_file"
    done
    echo -e "${CHECK} Log salvo com sucesso!"
fi

echo -e "${BLUE}Obrigado por usar o Assistente de Limpeza do macOS 🍏${RESET}"
