#!/bin/bash
# =================================================================
#  Portable AI USB - Start AI (macOS/Linux)
# =================================================================

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'
DIM='\033[90m'; BOLD='\033[1m'; RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"
ENGINE_DIR="$ROOT_DIR/engine"
DATA_DIR="$ROOT_DIR/data"
ENV_FILE="$DATA_DIR/ai_settings.env"
NODE_VERSION="22.14.0"

OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

if [ "$OS_NAME" = "darwin" ]; then
    PLATFORM="darwin"
elif [ "$OS_NAME" = "linux" ]; then
    PLATFORM="linux"
else
    echo -e "${RED}[ERROR] Unsupported OS: $OS_NAME${RESET}"
    exit 1
fi

if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then
    NODE_ARCH="x64"
elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
    NODE_ARCH="arm64"
else
    echo -e "${RED}[ERROR] Unsupported Architecture: $ARCH${RESET}"
    exit 1
fi

NODE_DIR_NAME="node-$PLATFORM-$NODE_ARCH"
NODE_DIR="$ENGINE_DIR/$NODE_DIR_NAME"
NODE_BIN="$NODE_DIR/bin/node"
NPM_BIN="$NODE_DIR/bin/npm"
NPX_BIN="$NODE_DIR/bin/npx"

mkdir -p "$ENGINE_DIR"

if [ ! -f "$NODE_BIN" ]; then
    echo -e "${YELLOW}[~] Node.js not found for $PLATFORM-$NODE_ARCH. Downloading...${RESET}"
    NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-${PLATFORM}-${NODE_ARCH}.tar.gz"
    TEMP_TAR="$ENGINE_DIR/node.tar.gz"
    curl -L "$NODE_URL" -o "$TEMP_TAR"
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERROR] Failed to download Node.js!${RESET}"
        exit 1
    fi
    mkdir -p "$NODE_DIR"
    tar -xzf "$TEMP_TAR" -C "$NODE_DIR" --strip-components=1
    rm "$TEMP_TAR"
    echo -e "${GREEN}[OK] Node.js installed to $NODE_DIR${RESET}"
fi

export PATH="$NODE_DIR/bin:$PATH"

# Ensure a package.json exists so npm installs locally (not globally)
if [ ! -f "$ENGINE_DIR/package.json" ]; then
    echo '{"name":"openclaude-portable","version":"1.0.0","private":true}' > "$ENGINE_DIR/package.json"
fi

if [ ! -d "$ENGINE_DIR/node_modules/@gitlawb/openclaude" ]; then
    echo -e "${YELLOW}[~] Installing OpenClaude Engine...${RESET}"
    cd "$ENGINE_DIR"
    npm install @gitlawb/openclaude@latest --no-audit --no-fund --loglevel=error --no-bin-links
    echo -e "${GREEN}[OK] Engine installed!${RESET}"
fi

# Portable data
export CLAUDE_CONFIG_DIR="$DATA_DIR/openclaude"
export XDG_CONFIG_HOME="$DATA_DIR/config"
export XDG_DATA_HOME="$DATA_DIR/app_data"
mkdir -p "$CLAUDE_CONFIG_DIR" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$DATA_DIR"

# Banner
echo ""
echo -e "${CYAN}    ____            __        __    __        ___    ____${RESET}"
echo -e "${CYAN}   / __ \\____  ____/ /_____ _/ /_  / /__     /   |  /  _/${RESET}"
echo -e "${CYAN}  / /_/ / __ \\/ __/ __/ __ \`/ __ \\/ / _ \\   / /| |  / /  ${RESET}"
echo -e "${CYAN} / ____/ /_/ / / / /_/ /_/ / /_/ / /  __/  / ___ |_/ /   ${RESET}"
echo -e "${CYAN}/_/    \\____/_/  \\__/\\__,_/_.___/_/\\___/  /_/  |_/___/   ${RESET}"
echo ""
echo -e "${CYAN}=========================================================${RESET}"
echo -e "  ${BOLD}Claude Code - Open Source Multi-Platform${RESET}"
echo -e "${CYAN}=========================================================${RESET}"
echo ""

# ─── Check for flags ────────────────────────────────────────
SKIP_UPDATE=0
QUICK_MODE=0
for arg in "$@"; do
    [ "$arg" = "--offline" ] && SKIP_UPDATE=1
    [ "$arg" = "--quick" ] && QUICK_MODE=1
done

# ─── Check for Engine Updates ────────────────────────────────
if [ $SKIP_UPDATE -eq 1 ]; then
    echo -e "  ${DIM}[~] Offline mode - skipping update check${RESET}"
else
    echo -e "  ${YELLOW}[~] Checking for engine updates...${RESET}"
    cd "$ENGINE_DIR"
    if npm outdated @gitlawb/openclaude 2>/dev/null | grep -q openclaude; then
        echo -e "  ${YELLOW}[~] New version detected! Upgrading...${RESET}"
        npm install @gitlawb/openclaude@latest --no-audit --no-fund --loglevel=error --no-bin-links >/dev/null 2>&1
        echo -e "  ${GREEN}[OK] Engine upgraded to latest version!${RESET}"
    else
        echo -e "  ${GREEN}[OK] Engine is up to date!${RESET}"
    fi
fi
echo ""

# ─── Check for settings ─────────────────────────────────────
goto_loaded=0
if [ -f "$ENV_FILE" ]; then
    # Strip \r to handle env files written on Windows (CRLF -> LF)
    ENV_CONTENT="$(cat "$ENV_FILE" 2>/dev/null | tr -d '\r' || true)"
    if [[ "$ENV_CONTENT" == *"AI_PROVIDER="* ]]; then
        # Load settings
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.* ]] && continue
            [ -z "$key" ] && continue
            value="${value%$'\r'}"  # strip trailing \r just in case
            export "$key=$value"
        done <<< "$ENV_CONTENT"
        goto_loaded=1
    fi
fi

# ─── Provider Setup ────────────────────────────────────────
save_env() {
    echo "$1" > "$ENV_FILE"
}

setup_provider() {
    echo -e "${CYAN}=========================================================${RESET}"
    echo -e "  ${BOLD}AI PROVIDER SELECTION${RESET}"
    echo -e "${CYAN}=========================================================${RESET}"
    echo ""
    echo -e "  ${CYAN}1)${RESET} ${BOLD}OpenRouter${RESET}   ${DIM}- 200+ Free and Paid Models${RESET}  ${GREEN}[RECOMMENDED]${RESET}"
    echo -e "  ${CYAN}2)${RESET} ${BOLD}NVIDIA NIM${RESET}   ${DIM}- High-Speed GPU Free Tier${RESET}   ${GREEN}[RECOMMENDED]${RESET}"
    echo -e "  ${CYAN}3)${RESET} ${BOLD}Gemini${RESET}       ${DIM}- Google AI API${RESET}"
    echo -e "  ${CYAN}4)${RESET} ${BOLD}Claude${RESET}       ${DIM}- Anthropic API${RESET}"
    echo -e "  ${CYAN}5)${RESET} ${BOLD}OpenAI${RESET}       ${DIM}- GPT / Codex API${RESET}"
    echo -e "  ${CYAN}6)${RESET} ${BOLD}Ollama${RESET}       ${DIM}- Local Offline AI (No internet)${RESET}"
    echo ""

    while true; do
        read -p "  Select your provider (1-6): " PROVIDER_SEL
        case "$PROVIDER_SEL" in
            1) setup_openrouter; return ;;
            2) setup_nvidia; return ;;
            3) setup_gemini; return ;;
            4) setup_claude; return ;;
            5) setup_openai; return ;;
            6) setup_ollama; return ;;
            *) echo -e "  ${RED}[ERROR] Invalid selection. Please choose 1-6.${RESET}" ;;
        esac
    done
}

verify_key() {
    local provider="$1" key="$2"
    echo -e "  ${YELLOW}[~] Verifying API Key... Please wait...${RESET}"
    case "$provider" in
        openrouter) curl -sf -H "Authorization: Bearer $key" https://openrouter.ai/api/v1/auth/key > /dev/null 2>&1 ;;
        gemini)     curl -sf "https://generativelanguage.googleapis.com/v1beta/models?key=$key" > /dev/null 2>&1 ;;
        anthropic)  curl -sf -H "x-api-key: $key" -H "anthropic-version: 2023-06-01" https://api.anthropic.com/v1/models > /dev/null 2>&1 ;;
        nvidia)     curl -sf -H "Authorization: Bearer $key" https://integrate.api.nvidia.com/v1/models > /dev/null 2>&1 ;;
        openai)     curl -sf -H "Authorization: Bearer $key" https://api.openai.com/v1/models > /dev/null 2>&1 ;;
    esac
}

mask_key() {
    local key="$1"
    echo "${key:0:6}****${key: -4}"
}

setup_openrouter() {
    echo ""
    echo -e "  ${CYAN}--- OPENROUTER SETUP ---${RESET}"
    echo ""
    read -p "  Enter your OpenRouter API Key: " USER_API_KEY
    [ -z "$USER_API_KEY" ] && echo -e "  ${RED}[ERROR] Key cannot be empty!${RESET}" && setup_openrouter && return
    echo -e "  ${DIM}Key: $(mask_key "$USER_API_KEY")${RESET}"
    echo ""
    if ! verify_key openrouter "$USER_API_KEY"; then
        echo -e "  ${RED}[ERROR] Invalid or expired OpenRouter API Key!${RESET}"
        setup_openrouter; return
    fi
    echo -e "  ${GREEN}[OK] Key Verified!${RESET}"
    echo ""

    # Model selection
    echo -e "  ${CYAN}1)${RESET} Free Models"
    echo -e "  ${CYAN}2)${RESET} Paid Models"
    read -p "  Select category (1 or 2): " MODEL_TIER
    echo ""

    if [ "$MODEL_TIER" = "1" ]; then
        echo -e "  ${CYAN}--- FREE MODELS ---${RESET} ${DIM}(Fetching...)${RESET}"
        MODELS=$(curl -sf https://openrouter.ai/api/v1/models 2>/dev/null | grep -Eo '"id"[[:space:]]*:[[:space:]]*"[^"]*:free"' | sed -e 's/"id"[[:space:]]*:[[:space:]]*"//g' -e 's/"//g' | head -20)
    else
        echo -e "  ${CYAN}--- PAID MODELS ---${RESET} ${DIM}(Fetching...)${RESET}"
        MODELS=$(curl -sf https://openrouter.ai/api/v1/models 2>/dev/null | grep -Eo '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -e 's/"id"[[:space:]]*:[[:space:]]*"//g' -e 's/"//g' | grep -v ':free$' | head -20)
    fi

    if [ -z "$MODELS" ]; then
        echo -e "  ${YELLOW}[API Error] Could not fetch models. Enter manually.${RESET}"
        read -p "  Enter model string: " USER_MODEL
    else
        idx=1
        while IFS= read -r model; do
            echo -e "  ${CYAN}${idx})${RESET} $model"
            eval "MODEL_${idx}='$model'"
            idx=$((idx+1))
        done <<< "$MODELS"
        echo -e "  ${CYAN}${idx})${RESET} ${DIM}Custom Model...${RESET}"
        echo ""
        read -p "  Choose a model (1-$idx): " MODEL_SEL
        if [ "$MODEL_SEL" = "$idx" ]; then
            read -p "  Enter custom model string: " USER_MODEL
        else
            eval "USER_MODEL=\$MODEL_${MODEL_SEL}"
        fi
    fi

    save_env "# ========================================================
# Portable AI - Master Switchboard
# ========================================================
AI_PROVIDER=openai
CLAUDE_CODE_USE_OPENAI=1
OPENAI_API_KEY=${USER_API_KEY}
OPENAI_BASE_URL=https://openrouter.ai/api/v1
OPENAI_MODEL=${USER_MODEL}
AI_DISPLAY_MODEL=${USER_MODEL}"
}

setup_gemini() {
    echo ""
    echo -e "  ${CYAN}--- GEMINI SETUP ---${RESET}"
    echo ""
    read -p "  Enter your Gemini API Key: " USER_API_KEY
    [ -z "$USER_API_KEY" ] && echo -e "  ${RED}[ERROR] Key cannot be empty!${RESET}" && setup_gemini && return
    echo -e "  ${DIM}Key: $(mask_key "$USER_API_KEY")${RESET}"
    echo ""
    USER_API_KEY=$(echo "$USER_API_KEY" | tr -d ' ' | tr -d '\r')
    if ! verify_key gemini "$USER_API_KEY"; then
        echo -e "  ${RED}[ERROR] Invalid or expired Gemini API Key!${RESET}"
        setup_gemini; return
    fi
    echo -e "  ${GREEN}[OK] Key Verified!${RESET}"
    echo ""
    echo -e "  ${CYAN}--- GEMINI MODELS ---${RESET} ${DIM}(Fetching...)${RESET}"
    MODELS=$(curl -sf "https://generativelanguage.googleapis.com/v1alpha/models?key=$USER_API_KEY" 2>/dev/null | grep -Eo '"name"[[:space:]]*:[[:space:]]*"models/gemini-[^"]*"' | sed -e 's/"name"[[:space:]]*:[[:space:]]*"models\///g' -e 's/"//g' | grep -vE 'vision|embedding|banana|lyria|robot|research|computer' | head -40)

    if [ -z "$MODELS" ]; then
        echo -e "  ${YELLOW}[API Error] Could not fetch models. Enter manually.${RESET}"
        read -p "  Enter model string: " USER_MODEL
    else
        idx=1
        while IFS= read -r model; do
            [ -z "$model" ] && continue
            echo -e "  ${CYAN}${idx})${RESET} $model"
            eval "MODEL_${idx}='$model'"
            idx=$((idx+1))
        done <<< "$MODELS"
        echo -e "  ${CYAN}${idx})${RESET} ${DIM}Custom Model...${RESET}"
        echo ""
        read -p "  Choose a model (1-$idx) [Enter for 1]: " MODEL_SEL
        [ -z "$MODEL_SEL" ] && MODEL_SEL=1
        if [ "$MODEL_SEL" = "$idx" ]; then
            read -p "  Enter custom model string: " USER_MODEL
        else
            eval "USER_MODEL=\$MODEL_${MODEL_SEL}"
        fi
    fi
    save_env "AI_PROVIDER=gemini
CLAUDE_CODE_USE_GEMINI=1
GEMINI_API_KEY=${USER_API_KEY}
GEMINI_MODEL=${USER_MODEL}
AI_DISPLAY_MODEL=${USER_MODEL}"
}

setup_claude() {
    echo ""
    echo -e "  ${CYAN}--- CLAUDE SETUP ---${RESET}"
    echo ""
    read -p "  Enter your Anthropic API Key: " USER_API_KEY
    [ -z "$USER_API_KEY" ] && echo -e "  ${RED}[ERROR] Key cannot be empty!${RESET}" && setup_claude && return
    echo -e "  ${DIM}Key: $(mask_key "$USER_API_KEY")${RESET}"
    echo ""
    if ! verify_key anthropic "$USER_API_KEY"; then
        echo -e "  ${RED}[ERROR] Invalid or expired Anthropic API Key!${RESET}"
        setup_claude; return
    fi
    echo -e "  ${GREEN}[OK] Key Verified!${RESET}"
    echo ""
    read -p "  Enter Model (Enter for claude-3-7-sonnet-20250219): " USER_MODEL
    [ -z "$USER_MODEL" ] && USER_MODEL="claude-3-7-sonnet-20250219"
    save_env "AI_PROVIDER=anthropic
ANTHROPIC_API_KEY=${USER_API_KEY}
AI_DISPLAY_MODEL=${USER_MODEL}"
}

setup_ollama() {
    echo ""
    echo -e "  ${CYAN}--- OLLAMA LOCAL SETUP ---${RESET}"
    echo ""
    
    OLLAMA_BIN="$DATA_DIR/ollama/ollama"
    [ ! -f "$OLLAMA_BIN" ] && OLLAMA_BIN="$DATA_DIR/ollama/ollama-$PLATFORM"
    
    if [ ! -x "$OLLAMA_BIN" ]; then
        echo -e "  ${YELLOW}[!] Ollama Engine not found!${RESET}"
        setup_provider; return
    fi

    echo -e "  ${DIM}[~] Waking up offline model registry...${RESET}"
    export OLLAMA_MODELS="$DATA_DIR/ollama/data"
    "$OLLAMA_BIN" serve >/dev/null 2>&1 &
    TMP_PID=$!
    sleep 2
    
    MODELS=$("$OLLAMA_BIN" list 2>/dev/null | awk 'NR>1 {print $1}')
    
    kill "$TMP_PID" 2>/dev/null
    wait "$TMP_PID" 2>/dev/null || true
    
    if [ -z "$MODELS" ]; then
        echo -e "  ${YELLOW}[!] No local models found!${RESET}"
        sleep 2
        setup_provider; return
    fi

    idx=1
    declare -a SYS_MODELS
    echo -e "  ${CYAN}Installed Local Models:${RESET}"
    
    while IFS= read -r m; do
        if [ -n "$m" ]; then
            echo -e "  ${CYAN}${idx})${RESET} $m"
            SYS_MODELS[$idx]="$m"
            idx=$((idx+1))
        fi
    done <<< "$MODELS"

    echo ""
    read -p "  Select a model (1-$((idx-1))) [Enter for 1]: " SEL
    [ -z "$SEL" ] && SEL=1
    USER_MODEL="${SYS_MODELS[$SEL]}"
    
    if [ -z "$USER_MODEL" ]; then
        echo -e "  ${RED}[ERROR] Invalid selection.${RESET}"
        setup_provider; return
    fi

    save_env "AI_PROVIDER=ollama
CLAUDE_CODE_USE_OPENAI=1
OPENAI_API_KEY=ollama
OPENAI_BASE_URL=http://localhost:11434/v1
OPENAI_MODEL=${USER_MODEL}
AI_DISPLAY_MODEL=${USER_MODEL}"
}

setup_openai() {
    echo ""
    echo -e "  ${CYAN}--- OPENAI / CODEX SETUP ---${RESET}"
    echo ""
    read -p "  Enter your OpenAI API Key: " USER_API_KEY
    [ -z "$USER_API_KEY" ] && echo -e "  ${RED}[ERROR] Key cannot be empty!${RESET}" && setup_openai && return
    echo -e "  ${DIM}Key: $(mask_key "$USER_API_KEY")${RESET}"
    echo ""
    if ! verify_key openai "$USER_API_KEY"; then
        echo -e "  ${RED}[ERROR] Invalid or expired OpenAI API Key!${RESET}"
        setup_openai; return
    fi
    echo -e "  ${GREEN}[OK] Key Verified!${RESET}"
    echo ""
    read -p "  Enter Model (Enter for gpt-4o): " USER_MODEL
    [ -z "$USER_MODEL" ] && USER_MODEL="gpt-4o"
    save_env "AI_PROVIDER=openai
CLAUDE_CODE_USE_OPENAI=1
OPENAI_API_KEY=${USER_API_KEY}
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_MODEL=${USER_MODEL}
AI_DISPLAY_MODEL=${USER_MODEL}"
}

setup_nvidia() {
    echo ""
    echo -e "  ${CYAN}--- NVIDIA NIM SETUP ---${RESET}"
    echo ""
    read -p "  Enter your NVIDIA API Key: " USER_API_KEY
    [ -z "$USER_API_KEY" ] && echo -e "  ${RED}[ERROR] Key cannot be empty!${RESET}" && setup_nvidia && return
    echo -e "  ${DIM}Key: $(mask_key "$USER_API_KEY")${RESET}"
    echo ""
    if ! verify_key nvidia "$USER_API_KEY"; then
        echo -e "  ${RED}[ERROR] Invalid or expired NVIDIA API Key!${RESET}"
        setup_nvidia; return
    fi
    echo -e "  ${GREEN}[OK] Key Verified!${RESET}"
    echo ""

    CURATED="qwen/qwen2.5-coder-32b-instruct meta/llama-3.3-70b-instruct meta/llama-3.1-405b-instruct deepseek-ai/deepseek-v3.1-terminus"
    echo -e "  ${CYAN}--- NVIDIA MODELS ---${RESET} ${DIM}(Fetching...)${RESET}"
    LIVE=$(curl -sf -H "Authorization: Bearer $USER_API_KEY" https://integrate.api.nvidia.com/v1/models 2>/dev/null | grep -Eo '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -e 's/"id"[[:space:]]*:[[:space:]]*"//g' -e 's/"//g' | head -40)
    MODELS=""
    for m in $CURATED; do MODELS="${MODELS}${m}"$'\n'; done
    MODELS="${MODELS}${LIVE}"

    if [ -z "$MODELS" ]; then
        echo -e "  ${YELLOW}[API Error] Could not fetch models. Entering fallback...${RESET}"
        USER_MODEL="meta/llama-3.3-70b-instruct"
    else
        idx=1
        while IFS= read -r model; do
            [ -z "$model" ] && continue
            echo -e "  ${CYAN}${idx})${RESET} $model"
            eval "MODEL_${idx}='$model'"
            idx=$((idx+1))
        done <<< "$MODELS"
        echo -e "  ${CYAN}${idx})${RESET} ${DIM}Custom Model...${RESET}"
        echo ""
        read -p "  Choose a model (1-$idx) [Enter for 1]: " MODEL_SEL
        [ -z "$MODEL_SEL" ] && MODEL_SEL=1
        if [ "$MODEL_SEL" = "$idx" ]; then
            read -p "  Enter custom model string: " USER_MODEL
        else
            eval "USER_MODEL=\$MODEL_${MODEL_SEL}"
        fi
    fi

    # CLAUDE_CODE_AGENT_LIST_IN_MESSAGES=false: stops system-reminder blocks being
    # injected as content arrays, which strict providers like NVIDIA NIM reject with 400
    save_env "AI_PROVIDER=openai
CLAUDE_CODE_USE_OPENAI=1
OPENAI_API_KEY=${USER_API_KEY}
OPENAI_BASE_URL=https://integrate.api.nvidia.com/v1
OPENAI_MODEL=${USER_MODEL}
AI_DISPLAY_MODEL=${USER_MODEL}
CLAUDE_CODE_AGENT_LIST_IN_MESSAGES=false
CLAUDE_CODE_SIMPLE=1"
}

# ─── Main Flow ──────────────────────────────────────────────
if [ "$goto_loaded" -eq 0 ]; then
    setup_provider
    echo ""
    echo -e "  ${GREEN}[OK] Settings saved!${RESET}"
    echo ""
    # Reload (strip \r for cross-platform safety)
    ENV_CONTENT="$(cat "$ENV_FILE" 2>/dev/null | tr -d '\r' || true)"
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^#.* ]] && continue
        [ -z "$key" ] && continue
        value="${value%$'\r'}"
        export "$key=$value"
    done <<< "$ENV_CONTENT"
fi

# ─── Friendly Provider Name ────────────────────────────────
PROVIDER_NAME="$AI_PROVIDER"
case "$AI_PROVIDER" in
    openai)
        if [[ "$OPENAI_BASE_URL" == *"openrouter"* ]]; then PROVIDER_NAME="OpenRouter"
        elif [[ "$OPENAI_BASE_URL" == *"integrate.api.nvidia.com"* ]]; then PROVIDER_NAME="NVIDIA NIM"
        elif [[ "$OPENAI_BASE_URL" == *"api.openai.com"* ]]; then PROVIDER_NAME="OpenAI"
        elif [[ "$OPENAI_BASE_URL" == *"localhost:11434"* ]]; then PROVIDER_NAME="Ollama"
        fi ;;
    gemini)     PROVIDER_NAME="Google Gemini" ;;
    anthropic)  PROVIDER_NAME="Anthropic Claude" ;;
    ollama)     PROVIDER_NAME="Ollama (Local)" ;;
esac

echo -e "${CYAN}=========================================================${RESET}"
echo -e "  ${BOLD}Claude Code - Ready (Multi-Platform)${RESET}"
echo -e "${CYAN}=========================================================${RESET}"
echo ""
echo -e "  ${BOLD}Provider${RESET} : ${GREEN}${PROVIDER_NAME}${RESET}"
echo -e "  ${BOLD}Model${RESET}    : ${GREEN}${AI_DISPLAY_MODEL}${RESET}"
echo -e "  ${BOLD}Data${RESET}     : ${DIM}Portable Mode (No PC Leaks)${RESET}"
echo ""
echo -e "${CYAN}=========================================================${RESET}"
echo ""

# ─── Launch Mode ─────────────────────────────────────────────

CMD_ARGS=""
if [ $QUICK_MODE -eq 1 ]; then
    echo -e "  ${RED}${BOLD}QUICK LAUNCH - Limitless Mode${RESET}"
    echo -e "  ${RED}[!] Commands will execute without confirmation!${RESET}"
    CMD_ARGS="--dangerously-skip-permissions"
else
    while true; do
        echo -e "  ${BOLD}Select Action:${RESET}"
        echo -e "  🚀 ${CYAN}1)${RESET} ${GREEN}Launch AI${RESET}       ${DIM}- Normal Mode (Auto-starts in 10s)${RESET}"
        echo -e "  ⚡ ${CYAN}2)${RESET} ${RED}Limitless Mode${RESET}  ${DIM}- Auto-executes everything (Advanced)${RESET}"
        echo -e "  ${DIM}─────────────────────────────────────────────────────────${RESET}"
        echo -e "   ${CYAN}3)${RESET} ${BOLD}Open Dashboard${RESET}  ${DIM}- View your chats visually${RESET}"
        echo -e "   ${CYAN}4)${RESET} ${BOLD}Change Provider${RESET} ${DIM}- Switch your AI provider or API Key${RESET}"
        echo -e "   ${CYAN}5)${RESET} ${BOLD}Setup Offline${RESET}   ${DIM}- Download local AI models (Ollama)${RESET}"
        echo ""
        
        # Read with a visual 10-second countdown
        LAUNCH_MODE=""
        for i in {10..1}; do
            echo -ne "\r  Select action (1-5) [Auto in $i]: "
            if read -t 1 -n 1 LAUNCH_MODE; then
                break
            fi
        done
        if [ -z "$LAUNCH_MODE" ]; then
            LAUNCH_MODE="1"
            echo -ne "\r  Select action (1-5) [Auto in 0]: "
        fi
        echo ""

        case "$LAUNCH_MODE" in
            1)
                echo ""
                echo -e "  ${GREEN}[OK] Normal mode selected.${RESET}"
                break
                ;;
            2)
                echo ""
                echo -e "  ${RED}${BOLD}[!] LIMITLESS MODE ACTIVATED${RESET}"
                CMD_ARGS="--dangerously-skip-permissions"
                break
                ;;
            3)
                echo ""
                exec bash "$ROOT_DIR/tools/open_dashboard.sh"
                ;;
            4)
                echo ""
                exec bash "$ROOT_DIR/tools/change_provider.sh"
                ;;
            5)
                echo ""
                exec bash "$ROOT_DIR/tools/setup_local_models.sh"
                ;;
            *)
                echo -e "  ${RED}[ERROR] Invalid selection.${RESET}\n"
                ;;
        esac
    done
fi

if [ "$AI_PROVIDER" = "ollama" ]; then
    OLLAMA_BIN="$DATA_DIR/ollama/ollama"
    [ ! -f "$OLLAMA_BIN" ] && OLLAMA_BIN="$DATA_DIR/ollama/ollama-$PLATFORM"
    if [ -x "$OLLAMA_BIN" ]; then
        echo -e "  ${CYAN}[~] Starting Local Ollama Server...${RESET}"
        export OLLAMA_MODELS="$DATA_DIR/ollama/data"
        "$OLLAMA_BIN" serve >/dev/null 2>&1 &
        OLLAMA_PID=$!
        sleep 3
        echo -e "  ${GREEN}[OK] Ollama running!${RESET}"
        echo ""
    fi
fi

echo -e "  ${CYAN}[~] Starting AI Engine...${RESET}"
echo ""

# Map internal provider name to openclaude --provider flag
PROVIDER_ARGS=""
if [ -n "$AI_PROVIDER" ]; then
    OC_PROVIDER="$AI_PROVIDER"
    # NVIDIA NIM uses openai-compat internally but the engine expects --provider nvidia-nim
    if [ "$AI_PROVIDER" = "openai" ] && [[ "$OPENAI_BASE_URL" == *"integrate.api.nvidia.com"* ]]; then
        OC_PROVIDER="nvidia-nim"
    fi
    PROVIDER_ARGS="--provider $OC_PROVIDER"
fi

cd "$ENGINE_DIR"

# Use portable binary directly (not npx)
OC_BIN="$ENGINE_DIR/node_modules/@gitlawb/openclaude/bin/openclaude"
if [ -f "$OC_BIN" ]; then
    "$NODE_BIN" "$OC_BIN" $PROVIDER_ARGS $CMD_ARGS
else
    npx openclaude $PROVIDER_ARGS $CMD_ARGS
fi

if [ -n "$OLLAMA_PID" ]; then
    echo ""
    echo -e "  ${CYAN}[~] Stopping Local Ollama Server...${RESET}"
    kill "$OLLAMA_PID" 2>/dev/null
    wait "$OLLAMA_PID" 2>/dev/null
fi
