#!/usr/bin/env bash
# Build and start the Safe Playground stack with Docker.
#
#   ./start.sh          # backend + web
#   ./start.sh --demo   # plus a synthetic camera and a seeded camera entry
set -euo pipefail

cd "$(dirname "$0")"

demo=0
open_browser=1
for arg in "$@"; do
    case "$arg" in
        --demo) demo=1 ;;
        --no-browser) open_browser=0 ;;
        -h|--help)
            sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

if ! command -v docker >/dev/null 2>&1; then
    cat >&2 <<'MSG'
Docker was not found.

Install Docker Engine or Docker Desktop, then run this script again:
  https://docs.docker.com/engine/install/

You do not need Flutter, Java, Maven, Python or Node on the host.
MSG
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "Docker is installed but not running (or the current user cannot access it)." >&2
    exit 1
fi

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    compose=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
    compose=(docker-compose)
else
    echo "docker compose is not available." >&2
    exit 1
fi

if [ ! -f .env ]; then
    cp .env.example .env
    echo "Created .env from .env.example (change the secrets before sharing)."
fi

web_port="$(sed -n 's/^WEB_PORT=//p' .env | tail -n1)"
web_port="${web_port:-5173}"
camera_port="$(sed -n 's/^CAMERA_PORT=//p' .env | tail -n1)"
camera_port="${camera_port:-8090}"
demo_url="$(sed -n 's/^DEMO_CAMERA_URL=//p' .env | tail -n1)"
demo_url="${demo_url:-http://localhost:${camera_port}/stream.mjpg}"
admin_user="$(sed -n 's/^INITIAL_ADMIN_USERNAME=//p' .env | tail -n1)"
admin_user="${admin_user:-playground}"
admin_password="$(sed -n 's/^INITIAL_ADMIN_PASSWORD=//p' .env | tail -n1)"
admin_password="${admin_password:-playground-demo}"

profiles=()
up_args=(up --build -d)
if [ "$demo" -eq 1 ]; then
    profiles=(--profile demo)
    up_args=(--profile demo up --build -d)
fi

echo
echo "Building and starting containers (the first run downloads images)..."
"${compose[@]}" "${up_args[@]}"
echo
echo "Waiting for the operator app on http://localhost:${web_port} ..."

url="http://localhost:${web_port}"
ready=0
for _ in $(seq 1 90); do
    if command -v curl >/dev/null 2>&1; then
        if curl -fsS -o /dev/null --max-time 2 "$url"; then ready=1; break; fi
    elif python3 -c "import urllib.request,sys; urllib.request.urlopen(sys.argv[1], timeout=2)" "$url" >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 2
done

if [ "$ready" -ne 1 ]; then
    echo "The stack is still starting. Check it with: ${compose[*]} logs -f" >&2
    exit 1
fi

cat <<EOF

Operator app : $url
Backend API  : http://localhost:8086
EOF
if [ "$demo" -eq 1 ]; then
    echo "Demo stream  : $demo_url"
fi
cat <<EOF
Login        : ${admin_user} / ${admin_password}

Add your own camera in the app with stream URL:
  ${demo_url}

Stop with: ${compose[*]} down
EOF
if [ "$demo" -eq 1 ]; then
    echo "Reset all data with: ${compose[*]} --profile demo down -v"
fi

if [ "$open_browser" -eq 1 ]; then
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$url" >/dev/null 2>&1 || true
    elif command -v open >/dev/null 2>&1; then
        open "$url" >/dev/null 2>&1 || true
    fi
fi
