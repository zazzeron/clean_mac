#!/bin/bash

# Cores para um visual suave e "Apple-like"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'
WHITE='\033[1;37m'

# Emojis do macOS e ícones para deixar mais atraente
INFO="ℹ️  "
CHECK="✅  "
WARNING="⚠️  "
BROOM="🧹  "
TRASH="🗑️  "
CLEANING="🧼  "
CLOUD="☁️  "
HOURGLASS="⌛  "
FIRED="🔥  "

# Função para verificar se o diretório é protegido (não apagável)
check_system_important() {
    local dir="$1"

    # Diretórios protegidos (exemplo)
    local protected_dirs=(
        "/System"
        "/bin"
        "/sbin"
        "/usr"
        "/var"
        "/Library"
    )

    for protected in "${protected_dirs[@]}"; do
        if [[ "$dir" == "$protected"* ]]; then
            echo -e "${WARNING} ⚠️  Diretório protegido: $dir NÃO será apagado."
            return 1  # Retorna 1 indicando que o diretório é protegido
        fi
    done

    return 0  # Retorna 0 indicando que o diretório pode ser limpo
}

# Variáveis
simulate=false
verbose=true
total_freed=0
log_file="cleaning_log.txt"

# Listas de status
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
    echo -e "${RED}🚨 Erro: Este script precisa ser executado com permissões de superusuário (sudo).${RESET}"
    echo -e "${YELLOW}💡 Para corrigir isso, execute o script com sudo: ${RESET}${GREEN}sudo bash nome_do_script.sh${RESET}"
    exit 1
fi

# 📋 Introdução com estilo
echo -e "${BLUE}🍏  Bem-vindo ao Assistente de Limpeza do macOS${RESET}"
echo -e "${CYAN}Liberando espaço de forma segura e eficiente!${RESET}\n"

# Simulação
echo -e "${INFO} ℹ️  Deseja simular a limpeza (sem apagar nada)?"
select sim_option in "Sim (Recomendado)" "Não (Executar de verdade)"; do
    case $REPLY in
        1) simulate=true; break ;;
        2) simulate=false; break ;;
        *) echo -e "${WARNING} ⚠️ Opção inválida. Escolha 1 ou 2." ;;
    esac
done

# Verbosidade
echo -e "\n${INFO} ℹ️  Deseja ver detalhes durante a limpeza?"
select verb_option in "Sim (ver tudo)" "Não (modo silencioso)"; do
    case $REPLY in
        1) verbose=true; break ;;
        2) verbose=false; break ;;
        *) echo -e "${WARNING} ⚠️ Opção inválida. Escolha 1 ou 2." ;;
    esac
done

# Confirmação
echo -e "\n${INFO} ℹ️  Resumo da operação:"
echo -e "${TRASH} 🗑️  Modo: $([[ $simulate == true ]] && echo 'Simulação' || echo 'Real')"
echo -e "${CLOUD} ☁️  Detalhamento: $([[ $verbose == true ]] && echo 'Ligado' || echo 'Desligado')"

read -p $'\n❗  Tem certeza que deseja continuar? (s/N): ' confirm
if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
    echo -e "${WARNING} ⚠️  Operação cancelada pelo usuário. Nenhuma alteração foi feita.${RESET}"
    exit 0
fi

# Registrar o tempo de início
start_time=$(date +%s)

echo -e "\n${HOURGLASS} ⌛  Iniciando limpeza... Aguarde."
progress_bar

# Funções principais (com melhorias visuais)
get_size() {
    stat -f%z "$1"
}

check_directory_exists() {
    [ -d "$1" ]
}

clean_and_count() {
    local path="$1"
    local description="$2"

    # Verifica se o diretório é protegido
    if ! check_system_important "$path"; then
        return
    fi

    if ! check_directory_exists "$path"; then
        not_found_directories+=("$description → $path")
        return
    fi

    size_before=$(get_size "$path")

    # Limpeza ou simulação
    if [ "$simulate" = false ]; then
        sudo rm -rf "$path"/* 2>/dev/null
    else
        echo -e "${INFO} ℹ️  [SIMULAÇÃO] Removeria arquivos de: $path"
    fi

    total_freed=$((total_freed + size_before))
    successfully_cleaned+=("$description (${size_before} KB)")
    [ "$verbose" = true ] && echo -e "${CHECK} ✅  ${GREEN}$description limpo com sucesso (${size_before} KB)${RESET}"
}

clean_trash() {
    local trash_paths=("$HOME/.Trash" /Users/*/.Trash /Volumes/*/.Trashes)
    echo -e "${BROOM} 🧹  ${CYAN}Iniciando limpeza das lixeiras...${RESET}"
    echo -e "${CYAN}  --------------------------------------${RESET}"

    for trash in "${trash_paths[@]}"; do
        if ! check_directory_exists "$trash"; then
            not_found_directories+=("Lixeira → $trash")
            continue
        fi

        if [ "$simulate" = false ]; then
            sudo find "$trash" -type f -print0 | xargs -0 sudo rm -f
            sudo find "$trash" -type d -empty -delete 2>/dev/null
        else
            echo -e "${INFO} ℹ️  [SIMULAÇÃO] Esvaziaria: $trash"
        fi

        successfully_cleaned+=("Lixeira: $trash")
        [ "$verbose" = true ] && echo -e "${CHECK} ✅  Lixeira limpa: $trash"
        [ "$verbose" = true ] && echo -e ""
    done
}

clean_cache_user() {
    local cache_dir="$HOME/Library/Caches"
    local protected=( "CloudKit" "FamilyCircle" "com.apple.Safari" "com.apple.WebKit" "com.apple.AppStore" )

    echo -e "${CLEANING} 🧼  ${CYAN}Limpando cache do usuário...${RESET}"
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
            echo -e "${INFO} ℹ️  [SIMULAÇÃO] Removeria: $item"
        fi

        total_freed=$((total_freed + size_before))
        successfully_cleaned+=("Cache do usuário: $base (${size_before} KB)")
        [ "$verbose" = true ] && echo -e "${CHECK} ✅  Limpado: $item"
    done
}

# 🚀 Execução com design "Apple-like"
clean_trash
clean_cache_user

directories_to_clean=(
    "/Library/Caches"
    "$HOME/Library/Logs"
    "/private/var/log"
    "/private/var/folders"
    "/Library/Updates"
    "$HOME/Library/Containers"
    "$HOME/Library/Application Support/CrashReporter"
    "$HOME/Library/Saved Application State"
)

echo -e "\n${CYAN}  Iniciando limpeza de múltiplos diretórios...${RESET}"
echo -e "${CYAN}  --------------------------------------${RESET}"

# Aqui, usamos um loop para iterar sobre os diretórios, chamando a função diretamente
for dir in "${directories_to_clean[@]}"; do
    clean_and_count "$dir" "$(basename "$dir")"
done

# iCloud Trash
icloud_trash="$HOME/Library/Mobile Documents/com~apple~CloudDocs/.Trash"
check_directory_exists "$icloud_trash" && clean_and_count "$icloud_trash" "Lixeira do iCloud"

# Registrar o tempo de término
end_time=$(date +%s)
elapsed_time=$((end_time - start_time))
elapsed_minutes=$((elapsed_time / 60))
elapsed_seconds=$((elapsed_time % 60))

# ✅ Resumo final
echo -e "\n${CHECK} ✅  ---------- RESUMO DA LIMPEZA ----------"

if [ ${#successfully_cleaned[@]} -gt 0 ]; then
    echo -e "\n${CLEANING} 🧼  ${GREEN}Pastas limpas com sucesso:${RESET}"
    for dir in "${successfully_cleaned[@]}"; do
        echo -e "  ${CHECK} ✅  $dir"
    done
fi

if [ ${#ignored_directories[@]} -gt 0 ]; then
    echo -e "\n${WARNING} ⚠️  ${YELLOW}Pastas protegidas (não apagadas):${RESET}"
    for dir in "${ignored_directories[@]}"; do
        echo -e "  ${WARNING} ⚠️  $dir"
    done
fi

if [ ${#not_found_directories[@]} -gt 0 ]; then
    echo -e "\n${TRASH} 🗑️  ${RED}Pastas não encontradas ou inacessíveis:${RESET}"
    for dir in "${not_found_directories[@]}"; do
        echo -e "  ${TRASH} 🗑️  $dir"
    done
fi

freed_mb=$((total_freed / 1024))
freed_gb=$(awk "BEGIN { printf \"%.2f\", $freed_mb / 1024 }")
echo -e "\n${CHECK} ✅  Total de espaço liberado: ${GREEN}${freed_mb} MB (~${freed_gb} GB)${RESET}"

# Mostrar o tempo de execução
echo -e "\n${INFO} ℹ️  Tempo total de execução: ${elapsed_minutes} minutos e ${elapsed_seconds} segundos."
