#!/bin/bash
# =========================================================
# CJH PANEL - Automated Installation & Management Script
# Credit: ZAIRA x Jishnu
# =========================================================

set -e

# =========================================================
# CJH PANEL CONFIGURATION
# =========================================================

PANEL_NAME="CJH Panel"
PANEL_SHORT="CJH"
PANEL_CREDIT="ZAIRA x Jishnu"

# IMPORTANT:
# Replace YOUR-GITHUB-USERNAME with your GitHub username.
REPO_URL="${CJH_REPO_URL:-https://github.com/YOUR-GITHUB-USERNAME/CJH-Panel.git}"

MAIN_PORT="6767"
DEV_PORT="3000"

MAIN_SERVICE="cjh-main"
DEV_SERVICE="cjh-admin"

WORK_DIR=""

# =========================================================
# COLORS
# =========================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# =========================================================
# FIND / PREPARE WORK DIRECTORY
# =========================================================

if [ -f "package.json" ]; then
    WORK_DIR="."
elif [ -d "CJH-Panel" ]; then
    WORK_DIR="CJH-Panel"
else
    echo -e "${CYAN}Downloading ${PANEL_NAME}...${NC}"

    if ! git clone "$REPO_URL" CJH-Panel; then
        echo -e "${RED}Failed to clone CJH Panel repository.${NC}"
        echo -e "${YELLOW}Check REPO_URL inside install.sh.${NC}"
        exit 1
    fi

    WORK_DIR="CJH-Panel"
fi

cd "$WORK_DIR" || exit 1

# =========================================================
# BANNER
# =========================================================

print_banner() {
    clear 2>/dev/null || true

    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║                                                      ║"
    echo "║        ██████╗     ██╗██╗  ██╗                      ║"
    echo "║       ██╔════╝     ██║██║  ██║                      ║"
    echo "║       ██║          ██║███████║                      ║"
    echo "║       ██║          ██║██╔══██║                      ║"
    echo "║       ╚██████╗     ██║██║  ██║                      ║"
    echo "║        ╚═════╝     ╚═╝╚═╝  ╚═╝                      ║"
    echo "║                                                      ║"
    echo "║                 CJH PANEL INSTALLER                 ║"
    echo "║                                                      ║"
    echo "║                  ${PANEL_CREDIT}                  ║"
    echo "║                                                      ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# =========================================================
# LOG FUNCTIONS
# =========================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =========================================================
# PM2
# =========================================================

run_pm2() {
    if command -v pm2 &> /dev/null; then
        pm2 "$@"

    elif [ -x "./node_modules/.bin/pm2" ]; then
        ./node_modules/.bin/pm2 "$@"

    elif [ -x "/usr/local/bin/pm2" ]; then
        /usr/local/bin/pm2 "$@"

    else
        npx --no-install pm2 "$@" 2>/dev/null || npx pm2 "$@"
    fi
}

# =========================================================
# EXECUTE INSTALLATION STEP
# =========================================================

execute_step() {

    local msg="$1"
    shift

    local step_id="cjh_step_$RANDOM"
    local log_file="/tmp/${step_id}.log"

    rm -f "$log_file"

    printf "  ${CYAN}→${NC} %-42s " "$msg"

    "$@" > "$log_file" 2>&1 &
    local pid=$!

    local spinstr='|/-\'

    while kill -0 "$pid" 2>/dev/null; do

        local temp=${spinstr#?}

        printf "[%c]" "$spinstr"

        spinstr=$temp${spinstr%"$temp"}

        sleep 0.08

        printf "\b\b\b"

    done

    wait "$pid"
    local status=$?

    if [ "$status" -eq 0 ]; then

        printf "\r  ${GREEN}✓${NC} %-42s ${GREEN}[Done]${NC}\n" "$msg"

    else

        printf "\r  ${RED}✗${NC} %-42s ${RED}[Fail]${NC}\n" "$msg"

        echo
        echo "======================================================"
        echo -e "${RED}INSTALLATION STEP FAILED${NC}"
        echo "======================================================"

        echo -e "Step: ${BOLD}$msg${NC}"
        echo "Exit Code: $status"

        echo
        echo "Output / Reason:"

        if [ -s "$log_file" ]; then
            tail -n 60 "$log_file"
        else
            echo "No output was generated."
        fi

        echo "======================================================"
        echo -e "Installation stopped safely.\n"

        exit 1
    fi

    return "$status"
}

# =========================================================
# SYSTEM DEPENDENCIES
# =========================================================

check_system_deps() {

    if ! command -v curl &> /dev/null || \
       ! command -v git &> /dev/null || \
       ! command -v tar &> /dev/null; then

        if command -v apt-get &> /dev/null; then

            sudo apt-get update -y -q > /dev/null 2>&1 || true

            sudo apt-get install -y \
                curl \
                git \
                build-essential \
                ca-certificates \
                tar \
                xz-utils \
                unzip \
                -q > /dev/null 2>&1 || true

        elif command -v yum &> /dev/null; then

            sudo yum update -y -q > /dev/null 2>&1 || true

            sudo yum install -y \
                curl \
                git \
                make \
                gcc-c++ \
                ca-certificates \
                tar \
                xz \
                unzip \
                -q > /dev/null 2>&1 || true

        fi
    fi

    return 0
}

# =========================================================
# DOCKER INSTALLATION
# =========================================================

install_docker() {

    if ! command -v docker &> /dev/null; then

        log_info "Installing Docker..."

        curl -fsSL https://get.docker.com | sh > /dev/null 2>&1 || true

        if command -v systemctl &> /dev/null; then
            sudo systemctl enable --now docker > /dev/null 2>&1 || true

        elif command -v service &> /dev/null; then
            sudo service docker start > /dev/null 2>&1 || true
        fi
    fi

    if ! command -v docker &> /dev/null; then

        echo "Docker could not be installed automatically."

        return 1
    fi

    if command -v systemctl &> /dev/null; then
        sudo systemctl start docker > /dev/null 2>&1 || true
    fi

    if ! docker compose version &> /dev/null && \
       ! command -v docker-compose &> /dev/null; then

        sudo curl -L \
        "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose \
        > /dev/null 2>&1 || true

        sudo chmod +x /usr/local/bin/docker-compose \
        > /dev/null 2>&1 || true
    fi

    if ! docker compose version &> /dev/null && \
       ! command -v docker-compose &> /dev/null; then

        echo "Docker Compose is required."

        return 1
    fi

    return 0
}

# =========================================================
# NODE.JS
# =========================================================

install_node() {

    local NEED_NODE=0

    if ! command -v node &> /dev/null; then

        NEED_NODE=1

    else

        local NODE_MAJOR

        NODE_MAJOR=$(node -v | tr -d 'v' | cut -d'.' -f1)

        if [ -z "$NODE_MAJOR" ] || [ "$NODE_MAJOR" -lt 20 ]; then
            NEED_NODE=1
        fi
    fi

    if [ "$NEED_NODE" -eq 1 ]; then

        if command -v apt-get &> /dev/null; then

            curl -fsSL \
            https://deb.nodesource.com/setup_22.x \
            | sudo -E bash - \
            > /dev/null 2>&1 || true

            sudo apt-get install -y nodejs \
            > /dev/null 2>&1 || true
        fi

        local CURRENT_MAJOR=0

        if command -v node &> /dev/null; then

            CURRENT_MAJOR=$(node -v | tr -d 'v' | cut -d'.' -f1)

        fi

        if [ "$CURRENT_MAJOR" -lt 20 ]; then

            local ARCH
            ARCH=$(uname -m)

            local NODE_ARCH="x64"

            case "$ARCH" in

                x86_64)
                    NODE_ARCH="x64"
                    ;;

                aarch64|arm64)
                    NODE_ARCH="arm64"
                    ;;

                armv7l)
                    NODE_ARCH="armv7l"
                    ;;

                *)
                    NODE_ARCH="x64"
                    ;;

            esac

            local NODE_DIST="node-v22.13.1-linux-${NODE_ARCH}"

            curl -fsSL \
            "https://nodejs.org/dist/v22.13.1/${NODE_DIST}.tar.xz" \
            -o /tmp/node22.tar.xz \
            > /dev/null 2>&1 || true

            if [ -f "/tmp/node22.tar.xz" ]; then

                sudo tar -xJf \
                /tmp/node22.tar.xz \
                -C /usr/local \
                --strip-components=1 \
                > /dev/null 2>&1 || true

                rm -f /tmp/node22.tar.xz
            fi
        fi
    fi

    if ! command -v node &> /dev/null; then

        echo "Node.js >=20 installation failed."

        return 1
    fi

    if ! command -v pm2 &> /dev/null; then

        sudo npm install -g pm2 \
        > /dev/null 2>&1 || true
    fi

    return 0
}

# =========================================================
# DOCKER ENVIRONMENT
# =========================================================

setup_docker_env() {

    install_docker

    if [ ! -f "Dockerfile" ]; then

cat << 'EOF2' > Dockerfile
FROM node:22-alpine

RUN apk add --no-cache \
    docker-cli \
    git \
    make \
    g++ \
    python3 \
    curl

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

RUN npm run build

EXPOSE 6767

CMD ["npm", "start"]
EOF2

    fi

    if [ ! -f "docker-compose.yml" ]; then

cat << 'EOF2' > docker-compose.yml
version: '3.8'

services:

  cjh-main:
    build: .
    container_name: cjh-main
    restart: unless-stopped

    ports:
      - "6767:6767"

    environment:
      - NODE_ENV=production
      - PORT=6767
      - CJH_HOST_DATA_PATH=${PWD}/.data

    volumes:
      - ./.data:/app/.data
      - ./backups:/app/backups
      - /var/run/docker.sock:/var/run/docker.sock

  cjh-admin:
    build: .
    container_name: cjh-admin
    restart: unless-stopped

    command: npm run dev

    ports:
      - "3000:3000"

    environment:
      - NODE_ENV=development
      - PORT=3000
      - CJH_HOST_DATA_PATH=${PWD}/.data

    volumes:
      - ./.data:/app/.data
      - ./backups:/app/backups
      - /var/run/docker.sock:/var/run/docker.sock
EOF2

    fi
}

# =========================================================
# NODE ENVIRONMENT
# =========================================================

setup_node_env() {

    install_node

    if [ ! -f "ecosystem.config.cjs" ]; then

cat << 'EOF2' > ecosystem.config.cjs
module.exports = {

  apps: [

    {
      name: "cjh-main",
      script: "npm",
      args: "start",
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: "1G",

      env: {
        NODE_ENV: "production",
        PORT: 6767
      }
    },

    {
      name: "cjh-admin",
      script: "npm",
      args: "run dev",
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: "2G",

      env: {
        NODE_ENV: "development",
        PORT: 3000
      }
    }

  ]

};
EOF2

    fi
}

# =========================================================
# INSTALL DEPENDENCIES
# =========================================================

install_dependencies() {

    if [ -f "package-lock.json" ]; then

        npm ci || npm install

    else

        npm install

    fi
}

# =========================================================
# OWNER ACCOUNT
# =========================================================

setup_owner() {

    if npm run | grep -q "createuser"; then

        npm run createuser

    else

        log_warning "createuser script not found."
        log_info "Skipping automatic owner creation."

    fi
}

# =========================================================
# BUILD
# =========================================================

build_application() {

    npm run build
}

# =========================================================
# START DOCKER PANEL
# =========================================================

start_panel_docker() {

    local TARGET="$1"

    if command -v docker-compose &> /dev/null; then

        docker-compose up -d --build "$TARGET"

    elif command -v docker &> /dev/null && \
         docker compose version &> /dev/null; then

        docker compose up -d --build "$TARGET"

    else

        echo "Docker Compose not found."

        return 1
    fi

    sleep 2

    local container_status

    container_status=$(docker inspect \
        --format '{{.State.Status}}' \
        "$TARGET" \
        2>/dev/null || echo "not_found")

    if [ "$container_status" == "exited" ] || \
       [ "$container_status" == "dead" ] || \
       [ "$container_status" == "not_found" ]; then

        echo "Docker container $TARGET failed to start."

        echo "--- Docker Logs ---"

        docker logs "$TARGET" --tail 40 2>&1 || true

        return 1
    fi

    return 0
}

# =========================================================
# START NODE PANEL
# =========================================================

start_panel_node() {

    local TARGET="$1"

    run_pm2 delete "$TARGET" 2>/dev/null || true

    run_pm2 start ecosystem.config.cjs --only "$TARGET"

    run_pm2 save --force 2>/dev/null || true
}

# =========================================================
# HEALTH CHECK
# =========================================================

health_check() {

    local PORT="$1"
    local RUNTIME_TYPE="$2"
    local TARGET="$3"

    local ATTEMPTS=0
    local MAX_ATTEMPTS=30

    while [ "$ATTEMPTS" -lt "$MAX_ATTEMPTS" ]; do

        if curl -s -f \
        "http://127.0.0.1:${PORT}/api/health" \
        >/dev/null 2>&1 || \
        curl -s -f \
        "http://127.0.0.1:${PORT}/" \
        >/dev/null 2>&1; then

            return 0
        fi

        if [ "$RUNTIME_TYPE" == "docker" ]; then

            local cstatus

            cstatus=$(docker inspect \
                --format '{{.State.Status}}' \
                "$TARGET" \
                2>/dev/null || echo "not_found")

            if [ "$cstatus" == "exited" ] || \
               [ "$cstatus" == "dead" ]; then

                echo "Container $TARGET exited."

                docker logs "$TARGET" \
                --tail 50 \
                2>&1 || true

                return 1
            fi

        else

            if run_pm2 list 2>/dev/null \
                | grep "$TARGET" \
                | grep -qE "errored|stopped"; then

                echo "PM2 process $TARGET crashed."

                run_pm2 logs "$TARGET" \
                --lines 40 \
                --nostream \
                2>&1 || true

                return 1
            fi
        fi

        sleep 2

        ATTEMPTS=$((ATTEMPTS + 1))

    done

    echo "Health check timed out on port $PORT."

    if [ "$RUNTIME_TYPE" == "docker" ]; then

        docker ps -a \
        --filter "name=$TARGET" || true

        docker logs "$TARGET" \
        --tail 50 \
        2>&1 || true

    else

        run_pm2 list || true

        run_pm2 logs "$TARGET" \
        --lines 50 \
        --nostream || true

    fi

    return 1
}

# =========================================================
# SHOW STATUS
# =========================================================

show_status() {

    local MAIN_STATUS="OFF"
    local DEV_STATUS="OFF"
    local SFTP_STATUS="OFF"

    if \
    (run_pm2 list 2>/dev/null \
        | grep "cjh-main" \
        | grep -q "online") || \
    (command -v docker &> /dev/null && \
        docker ps --format '{{.Names}}' \
        | grep -q "^cjh-main$") || \
    curl -s -m 2 \
        http://127.0.0.1:6767/api/health \
        2>/dev/null \
        | grep -q "Panel"; then

        MAIN_STATUS="ONLINE"
    fi

    if \
    (run_pm2 list 2>/dev/null \
        | grep "cjh-admin" \
        | grep -q "online") || \
    (command -v docker &> /dev/null && \
        docker ps --format '{{.Names}}' \
        | grep -q "^cjh-admin$") || \
    curl -s -m 2 \
        http://127.0.0.1:3000/api/health \
        2>/dev/null \
        | grep -q "Panel"; then

        DEV_STATUS="ONLINE"
    fi

    if [ "$MAIN_STATUS" == "ONLINE" ] || \
       [ "$DEV_STATUS" == "ONLINE" ]; then

        SFTP_STATUS="ONLINE"
    fi

    local IP

    IP=$(curl -s -m 2 ifconfig.me 2>/dev/null \
        || curl -s -m 2 icanhazip.com 2>/dev/null \
        || hostname -I 2>/dev/null | awk '{print $1}' \
        || echo "localhost")

    echo
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║                 CJH PANEL STATUS                    ║"
    echo "╠══════════════════════════════════════════════════════╣"
    echo "║                                                      ║"

    if [ "$MAIN_STATUS" == "ONLINE" ]; then

        echo -e "║  Main Panel      : ${GREEN}ONLINE${NC}"
        echo "║  Main URL        : http://${IP}:6767"

    else

        echo -e "║  Main Panel      : ${RED}OFF${NC}"

    fi

    echo "║  Main Port       : 6767"

    if [ "$DEV_STATUS" == "ONLINE" ]; then

        echo -e "║  Developer Panel : ${GREEN}ONLINE${NC}"
        echo "║  Developer URL   : http://${IP}:3000"

    else

        echo -e "║  Developer Panel : ${YELLOW}OFF${NC}"

    fi

    echo "║  Developer Port  : 3000"

    if [ "$SFTP_STATUS" == "ONLINE" ]; then

        echo -e "║  SFTP Service    : ${GREEN}ONLINE${NC}"

    else

        echo -e "║  SFTP Service    : ${RED}OFF${NC}"

    fi

    echo "║"
    echo "║  Credit          : ZAIRA x Jishnu"
    echo "║"
    echo "╚══════════════════════════════════════════════════════╝"

    echo -e "${NC}"
}

# =========================================================
# INSTALL PANEL
# =========================================================

install_panel() {

    local TARGET="$1"

    local PANEL_NAME="Main Panel"
    local PORT="$MAIN_PORT"
    local SERVICE_NAME="$MAIN_SERVICE"

    if [ "$TARGET" == "dev" ]; then

        PANEL_NAME="Developer Panel"
        PORT="$DEV_PORT"
        SERVICE_NAME="$DEV_SERVICE"

    fi

    print_banner

    echo "╔══════════════════════════════════════════════════════╗"
    echo "║              SELECT INSTALLATION MODE               ║"
    echo "╠══════════════════════════════════════════════════════╣"
    echo "║                                                      ║"
    echo "║  1) Docker                                           ║"
    echo "║  2) Local Node.js                                    ║"
    echo "║  3) Back                                             ║"
    echo "║                                                      ║"
    echo "╚══════════════════════════════════════════════════════╝"

    local MODE_CHOICE=""

    if [ -n "$RUN_CHOICE" ]; then

        MODE_CHOICE="$RUN_CHOICE"

    else

        read -p " Choose an option (1-3): " MODE_CHOICE

    fi

    if [ "$MODE_CHOICE" == "3" ]; then
        return
    fi

    if [ "$MODE_CHOICE" != "1" ] && \
       [ "$MODE_CHOICE" != "2" ]; then

        log_error "Invalid selection."

        sleep 1

        return
    fi

    # =====================================================
    # OWNER
    # =====================================================

    if [ "$TARGET" == "main" ]; then

        print_banner

        echo "╔══════════════════════════════════════════════════════╗"
        echo "║                 CREATE OWNER ACCOUNT                ║"
        echo "╠══════════════════════════════════════════════════════╣"

        local OWNER_USER=""
        local OWNER_PASS=""
        local OWNER_PASS2=""

        if [ -n "$CJH_OWNER_USER" ] && \
           [ -n "$CJH_OWNER_PASS" ]; then

            OWNER_USER="$CJH_OWNER_USER"
            OWNER_PASS="$CJH_OWNER_PASS"

        else

            while true; do

                read -p "║ Username: " OWNER_USER

                if [ -n "$OWNER_USER" ]; then
                    break
                fi

            done

            while true; do

                read -s -p "║ Password: " OWNER_PASS
                echo ""

                read -s -p "║ Confirm Password: " OWNER_PASS2
                echo ""

                if [ "$OWNER_PASS" == "$OWNER_PASS2" ] && \
                   [ -n "$OWNER_PASS" ]; then

                    break

                else

                    echo "║ Passwords do not match or are empty."

                fi

            done
        fi

        echo "╚══════════════════════════════════════════════════════╝"

        export CJH_OWNER_USER="$OWNER_USER"
        export CJH_OWNER_PASS="$OWNER_PASS"

    fi

    # =====================================================
    # ENVIRONMENT
    # =====================================================

    mkdir -p .data backups

    if [ ! -f ".env" ]; then

        if [ -f ".env.example" ]; then

            cp .env.example .env

        else

            echo "PORT=$PORT" > .env

            echo "JWT_SECRET=$(head -c 32 /dev/urandom | base64 2>/dev/null || openssl rand -base64 32)" >> .env

        fi
    fi

    print_banner

    echo "╔══════════════════════════════════════════════════════╗"
    echo "║              INSTALLATION PROGRESS                  ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo

    execute_step \
        "System Requirement Check" \
        check_system_deps

    if [ "$MODE_CHOICE" == "1" ]; then

        execute_step \
            "Docker Configuration" \
            setup_docker_env

        execute_step \
            "Node Environment" \
            install_node

        execute_step \
            "NPM Dependencies" \
            install_dependencies

        if [ "$TARGET" == "main" ]; then

            execute_step \
                "Owner Account Setup" \
                setup_owner

            execute_step \
                "Building & Starting CJH Container" \
                start_panel_docker \
                cjh-main

            execute_step \
                "Waiting for CJH Panel Port 6767" \
                health_check \
                6767 \
                docker \
                cjh-main

        else

            execute_step \
                "Building & Starting CJH Developer Container" \
                start_panel_docker \
                cjh-admin

            execute_step \
                "Waiting for Developer Port 3000" \
                health_check \
                3000 \
                docker \
                cjh-admin

        fi

    else

        execute_step \
            "Node.js Configuration" \
            setup_node_env

        execute_step \
            "NPM Dependencies" \
            install_dependencies

        if [ "$TARGET" == "main" ]; then

            execute_step \
                "Owner Account Setup" \
                setup_owner

            execute_step \
                "Building CJH Panel" \
                build_application

            execute_step \
                "Starting CJH PM2 Service" \
                start_panel_node \
                cjh-main

            execute_step \
                "Waiting for CJH Panel Port 6767" \
                health_check \
                6767 \
                pm2 \
                cjh-main

        else

            execute_step \
                "Building Developer Panel" \
                build_application

            execute_step \
                "Starting CJH Developer Service" \
                start_panel_node \
                cjh-admin

            execute_step \
                "Waiting for Developer Port 3000" \
                health_check \
                3000 \
                pm2 \
                cjh-admin

        fi

    fi

    show_status

    local IP

    IP=$(curl -s -m 2 ifconfig.me 2>/dev/null \
        || curl -s -m 2 icanhazip.com 2>/dev/null \
        || hostname -I 2>/dev/null | awk '{print $1}' \
        || echo "localhost")

    if [ "$TARGET" == "
