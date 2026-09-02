#!/usr/bin/env bash
#
# connect-cursor-cai.sh
#
# Automates connecting Cursor IDE to a Cloudera AI project via Remote SSH.
# Hackathon guide: https://superellipse.github.io/zeta-hol/vibe-coding/cursor-remote-ssh/
#
# =============================================================================
# STOP — CHECK THESE PREREQUISITES BEFORE RUNNING
# =============================================================================
#
# You MUST complete every item below. The script will not work otherwise.
#
# 1. cdswctl CLI
#    - Download for your OS from Cloudera AI:
#      User Settings → Keys & Access → Remote Editing
#    - Unpack and add the folder containing `cdswctl` to your PATH
#    - macOS: allow the binary in System Settings → Privacy & Security
#      if Gatekeeper blocks it (see the guide above)
#
# 2. SSH key for remote editing
#    - Generate:  ssh-keygen -C cai
#    - When prompted for the file name, type exactly:  cai
#      Do NOT accept the default (id_ed25519) or use your own name —
#      the script and SSH config expect ~/.ssh/cai and ~/.ssh/cai.pub
#    - Move keys: mv cai cai.pub ~/.ssh/
#    - Copy public key:  cat ~/.ssh/cai.pub
#    - Paste into Cloudera AI:
#      User Settings → Keys & Access → Remote Editing → SSH Public Key
#
# 3. API key for CLI authentication
#    - Create in Cloudera AI:
#      User Settings → Keys & Access → API Keys
#    - Do NOT use a Legacy API key — create a new API key instead
#    - Save the key immediately — it is shown only once
#    - Add it to connect-cai.env (see connect-cai.env.example)
#
# 4. Team project assigned (MANDATORY)
#    - Your hackathon project is pre-created as teamXX-project (XX = your team number)
#    - PROJECT_NAME in connect-cai.env MUST be the full project slug:
#        <your-username>/teamXX-project
#    - Example: PROJECT_NAME="your-username/team07-project"
#    - Do NOT set PROJECT_NAME to just the project name (e.g. "team07-project" will fail)
#    - Copy the full slug from the browser URL when you open your assigned project
#
# 5. jq (JSON parser)
#    - Required for automatic runtime/add-on selection
#    - macOS:  brew install jq
#
# =============================================================================
# QUICK START
# =============================================================================
#
#   cp connect-cai.env.example connect-cai.env   # fill in your values
#   CONNECT_CAI_ENV=./connect-cai.env ./connect-cursor-cai.sh
#
# Keep this terminal open while using Cursor. Press Ctrl+C to stop the tunnel.
#
# Optional flags:
#   --gpu           Select an Nvidia GPU runtime edition (default: Standard)
#   --spark         Attach a Spark runtime add-on (default Spark version: 3.4)
#   --new-session   Always start a new session (skip reuse of existing ones)
#   --tunnel-only   Skip session creation; use SESSION_ID from connect-cai.env
#   --help          Show usage
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${CONNECT_CAI_ENV:-${SCRIPT_DIR}/connect-cai.env}"

# Defaults (overridden by connect-cai.env)
PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
SESSION_CPU="${SESSION_CPU:-2}"
SESSION_MEMORY="${SESSION_MEMORY:-4}"
SESSION_GPU="${SESSION_GPU:-0}"
USE_GPU="${USE_GPU:-false}"
USE_SPARK="${USE_SPARK:-false}"
SPARK_VERSION="${SPARK_VERSION:-3.4}"
SSH_LOCAL_PORT="${SSH_LOCAL_PORT:-3735}"
SSH_HOST_ALIAS="${SSH_HOST_ALIAS:-cai-workbench}"
SSH_IDENTITY_FILE="${SSH_IDENTITY_FILE:-${HOME}/.ssh/cai}"

FORCE_NEW_SESSION=false
TUNNEL_ONLY=false

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

info()  { printf '==> %s\n' "$*" >&2; }
warn()  { printf 'warning: %s\n' "$*" >&2; }
error() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Show paths with ~ instead of /Users/<you>/... in user-facing output
path_for_display() {
  local p="$1"
  if [[ "$p" == "${HOME}"/* ]]; then
    printf '~%s' "${p#"${HOME}"}"
  else
    printf '%s' "$p"
  fi
}

usage() {
  sed -n '2,/^set -euo pipefail$/p' "$0" | head -n -1 | tail -n +2
  exit 0
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --gpu)          USE_GPU=true; shift ;;
      --spark)        USE_SPARK=true; shift ;;
      --new-session)  FORCE_NEW_SESSION=true; shift ;;
      --tunnel-only)  TUNNEL_ONLY=true; shift ;;
      --help|-h)      usage ;;
      *)
        error "Unknown option: $1 (try --help)"
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

load_env() {
  if [[ ! -f "$ENV_FILE" ]]; then
    error "Config file not found: $ENV_FILE

Copy the example and fill in your values:
  cp ${SCRIPT_DIR}/connect-cai.env.example ${SCRIPT_DIR}/connect-cai.env"
  fi

  # shellcheck disable=SC1090
  source "$ENV_FILE"

  : "${CAI_DOMAIN:?Set CAI_DOMAIN in ${ENV_FILE}}"
  : "${CAI_USERNAME:?Set CAI_USERNAME in ${ENV_FILE}}"
  : "${API_KEY:?Set API_KEY in ${ENV_FILE}}"
  : "${PROJECT_NAME:?Set PROJECT_NAME in ${ENV_FILE}}"

  # Expand ~ in SSH key paths
  SSH_IDENTITY_FILE="${SSH_IDENTITY_FILE/#\~/$HOME}"
  SSH_PUBLIC_KEY_FILE="${SSH_PUBLIC_KEY_FILE:-${SSH_IDENTITY_FILE}.pub}"
  SSH_PUBLIC_KEY_FILE="${SSH_PUBLIC_KEY_FILE/#\~/$HOME}"
}

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------

print_prerequisite_banner() {
  cat >&2 <<'EOF'

*******************************************************************************
  STOP — Have you completed all prerequisite steps? (see script header)
*******************************************************************************
  The script will verify each item below before continuing:

  [1] cdswctl installed and on PATH
  [2] jq installed and on PATH
  [3] SSH key pair generated (~/.ssh/cai and ~/.ssh/cai.pub)
  [4] API_KEY set in connect-cai.env (current CAI API key, not Legacy)
  [5] PROJECT_NAME set to <CAI_USERNAME>/<project-name>
  [6] SSH public key uploaded to CAI → User Settings → Remote Editing
      (cannot be verified automatically — you must confirm this yourself)
*******************************************************************************

EOF
}

check_cdswctl() {
  if ! command -v cdswctl >/dev/null 2>&1; then
    error "[1/6] cdswctl not found in PATH.

Download it from Cloudera AI → User Settings → Keys & Access → Remote Editing
and add the folder to your PATH."
  fi
  if ! cdswctl version >/dev/null 2>&1; then
    error "[1/6] cdswctl is on PATH but failed to run.

On macOS, allow it in System Settings → Privacy & Security if Gatekeeper blocked it."
  fi
  info "[1/6] cdswctl: OK"
}

check_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    error "[2/6] jq not found. Install it (e.g. brew install jq) for runtime auto-selection."
  fi
  if ! jq --version >/dev/null 2>&1; then
    error "[2/6] jq is on PATH but failed to run."
  fi
  info "[2/6] jq: OK"
}

check_ssh_keys() {
  if [[ ! -f "$SSH_IDENTITY_FILE" ]]; then
    error "[3/6] SSH private key not found at: ${SSH_IDENTITY_FILE}

Generate with: ssh-keygen -C cai
When prompted for file location, save as: ${SSH_IDENTITY_FILE}"
  fi

  if [[ ! -f "$SSH_PUBLIC_KEY_FILE" ]]; then
    error "[3/6] SSH public key not found at: ${SSH_PUBLIC_KEY_FILE}

Generate the key pair with: ssh-keygen -C cai
Expected files:
  ${SSH_IDENTITY_FILE}
  ${SSH_PUBLIC_KEY_FILE}"
  fi

  if ! ssh-keygen -y -f "$SSH_IDENTITY_FILE" >/dev/null 2>&1; then
    error "[3/6] SSH private key at ${SSH_IDENTITY_FILE} is invalid or passphrase-protected.

Use a key without a passphrase for cdswctl remote SSH, or generate a new one:
  ssh-keygen -C cai -f ${SSH_IDENTITY_FILE} -N \"\""
  fi

  info "[3/6] SSH key pair: OK ($(path_for_display "$SSH_IDENTITY_FILE"))"
}

check_api_key_config() {
  if [[ -z "${API_KEY//[[:space:]]/}" ]]; then
    error "[4/6] API_KEY is not set in ${ENV_FILE}."
  fi

  if [[ "$API_KEY" == "your-api-key" ]] || [[ "$API_KEY" == "your-rotated-api-key" ]] || [[ "$API_KEY" == *"your-api"* ]]; then
    error "[4/6] API_KEY still has the placeholder value in ${ENV_FILE}.

Create an API key in Cloudera AI → User Settings → Keys & Access → API Keys
and paste it into API_KEY. Do NOT use a Legacy API key."
  fi

  if [[ ${#API_KEY} -lt 32 ]]; then
    error "[4/6] API_KEY in ${ENV_FILE} looks too short to be valid.

Create a new API key in Cloudera AI → User Settings → Keys & Access → API Keys."
  fi

  info "[4/6] API_KEY configured in ${ENV_FILE}: OK"
}

check_project_name() {
  if [[ ! "$PROJECT_NAME" =~ / ]]; then
    error "[5/6] PROJECT_NAME must be the full project slug: <CAI_USERNAME>/<project-name>

You set: ${PROJECT_NAME}

Example: PROJECT_NAME=\"${CAI_USERNAME}/my-project\"

Create the project in Cloudera AI Workbench first, then use the full slug
from the browser URL bar (owner/project-name)."
  fi

  info "[5/6] PROJECT_NAME: OK (${PROJECT_NAME})"
}

remind_ssh_public_key_in_cai() {
  warn "[6/6] SSH public key in CAI cannot be verified automatically."
  warn "      Confirm you have pasted this key into Cloudera AI:"
  warn "      User Settings → Keys & Access → Remote Editing → SSH Public Key"
  warn "      Public key file: $(path_for_display "$SSH_PUBLIC_KEY_FILE")"
  warn "      Preview: $(head -c 60 "${SSH_PUBLIC_KEY_FILE}")..."
}

check_prerequisites() {
  print_prerequisite_banner
  info "Running prerequisite checks..."

  check_cdswctl
  check_jq
  check_ssh_keys
  check_api_key_config
  check_project_name
  remind_ssh_public_key_in_cai

  info "Prerequisite checks passed (project: ${PROJECT_NAME})"
}

# ---------------------------------------------------------------------------
# Login
# ---------------------------------------------------------------------------

login_to_cai() {
  info "Logging in to ${CAI_DOMAIN} as ${CAI_USERNAME}..."

  local output
  local exit_code=0
  output="$(cdswctl login -n "$CAI_USERNAME" -u "$CAI_DOMAIN" -y "$API_KEY" 2>&1)" || exit_code=$?

  if [[ "$output" == *"Login succeeded"* ]]; then
    info "Login succeeded"
    return 0
  fi

  printf '%s\n' "$output" >&2
  error "Login failed (exit ${exit_code}). Check CAI_DOMAIN, CAI_USERNAME, and API_KEY in ${ENV_FILE}.

Use a current API key from User Settings → Keys & Access → API Keys.
Do not use a Legacy API key — create a new API key if login returns 401."
}

# ---------------------------------------------------------------------------
# Runtime selection
# ---------------------------------------------------------------------------

resolve_runtime_id() {
  if [[ -n "${RUNTIME_ID:-}" ]]; then
    info "Using RUNTIME_ID from config: ${RUNTIME_ID}"
    echo "$RUNTIME_ID"
    return 0
  fi

  local edition="standard"
  if [[ "$USE_GPU" == "true" ]]; then
    edition="nvidia"
  fi

  info "Auto-selecting PBJ Workbench runtime (Python ${PYTHON_VERSION}, ${edition} edition)..."

  local runtime_id
  runtime_id="$(cdswctl runtimes list | jq -r \
    --arg py "python ${PYTHON_VERSION}" \
    --arg edition "$edition" '
    [.[]? | .[]? | select(
      (.kernel | ascii_downcase | contains($py | ascii_downcase)) and
      (.editor | ascii_downcase | contains("pbj")) and
      (.edition | ascii_downcase | contains($edition))
    )]
    | sort_by(.shortVersion) | reverse
    | .[0].id // empty
  ')"

  [[ -n "$runtime_id" ]] \
    || error "No matching PBJ Workbench runtime found for Python ${PYTHON_VERSION} (${edition}).

List available runtimes:
  cdswctl runtimes list | jq '.[]? | .[]? | {id, editor, kernel, edition, shortVersion}'

Or set RUNTIME_ID manually in ${ENV_FILE}."

  info "Selected runtime ID: ${runtime_id}"
  echo "$runtime_id"
}

# ---------------------------------------------------------------------------
# Spark add-on (optional)
# ---------------------------------------------------------------------------

resolve_addon_id() {
  if [[ "$USE_SPARK" != "true" ]]; then
    return 0
  fi

  if [[ -n "${ADDON_ID:-}" ]]; then
    info "Using ADDON_ID from config: ${ADDON_ID}"
    echo "$ADDON_ID"
    return 0
  fi

  info "Auto-selecting Spark add-on (version ${SPARK_VERSION})..."

  local addon_id
  addon_id="$(cdswctl runtime-addons list | jq -r \
    --arg ver "$SPARK_VERSION" '
    [.[] | select(.component == "Spark" and (.displayName | contains($ver)))]
    | .[0].id // empty
  ')"

  [[ -n "$addon_id" ]] \
    || error "No Spark ${SPARK_VERSION} add-on found.

List available add-ons:
  cdswctl runtime-addons list | jq '.[] | select(.component==\"Spark\")'

Or set ADDON_ID manually in ${ENV_FILE}."

  info "Selected Spark add-on ID: ${addon_id}"
  echo "$addon_id"
}

# ---------------------------------------------------------------------------
# Session management
# ---------------------------------------------------------------------------

find_existing_session() {
  local list_output
  list_output="$(cdswctl sessions list --project="$PROJECT_NAME" 2>/dev/null || true)"

  # Empty output means no active sessions
  [[ -n "${list_output//[[:space:]]/}" ]] || return 1

  local session_id=""

  # Prefer sessions that are scheduling, starting, or running
  session_id="$(printf '%s\n' "$list_output" \
    | grep -Ei '(scheduling|starting|running)' \
    | head -1 \
    | sed -E 's/^([a-zA-Z0-9]+).*/\1/' \
    || true)"

  # Fallback: first token before ':' on any non-empty line
  if [[ -z "$session_id" ]]; then
    session_id="$(printf '%s\n' "$list_output" \
      | grep -E '^[a-zA-Z0-9]+:' \
      | head -1 \
      | cut -d: -f1 \
      || true)"
  fi

  [[ -n "$session_id" ]] || return 1
  echo "$session_id"
}

start_session() {
  local runtime_id="$1"
  local addon_id="${2:-}"

  local -a start_args=(
    sessions start
    --memory="$SESSION_MEMORY"
    --cpu="$SESSION_CPU"
    --gpu="$SESSION_GPU"
    --runtime-id="$runtime_id"
    --project="$PROJECT_NAME"
  )

  if [[ -n "$addon_id" ]]; then
    start_args+=(--addons="$addon_id")
  fi

  info "Starting session (cpu=${SESSION_CPU}, memory=${SESSION_MEMORY}GB, gpu=${SESSION_GPU})..."

  local session_id
  session_id="$(cdswctl "${start_args[@]}")"

  [[ -n "$session_id" ]] || error "Failed to start session (empty session ID returned)."

  info "Session started: ${session_id}"
  echo "$session_id"
}

resolve_session_id() {
  local runtime_id="$1"
  local addon_id="${2:-}"

  if [[ -n "${SESSION_ID:-}" ]]; then
    info "Using SESSION_ID from config: ${SESSION_ID}"
    echo "$SESSION_ID"
    return 0
  fi

  if [[ "$FORCE_NEW_SESSION" != "true" ]]; then
    local existing
    existing="$(find_existing_session || true)"
    if [[ -n "$existing" ]]; then
      info "Reusing existing session: ${existing}"
      echo "$existing"
      return 0
    fi
  fi

  start_session "$runtime_id" "$addon_id"
}

# ---------------------------------------------------------------------------
# Local SSH port
# ---------------------------------------------------------------------------

port_is_available() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    ! lsof -nP -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1
    return
  fi
  # Fallback: try binding via bash /dev/tcp (connect succeeds if something listens)
  (echo >/dev/tcp/127.0.0.1/"${port}") 2>/dev/null && return 1
  return 0
}

find_available_port() {
  local preferred="$1"
  local port="$preferred"
  local max_attempts=50
  local attempt=0

  while (( attempt < max_attempts )); do
    if port_is_available "$port"; then
      if (( port != preferred )); then
        warn "Port ${preferred} is already in use; using port ${port} instead."
      fi
      echo "$port"
      return 0
    fi
    ((attempt++))
    ((port++))
  done

  error "No available local port found in range ${preferred}-$((preferred + max_attempts - 1)).

Stop any stale tunnel (e.g. a previous run still holding port ${preferred}) and try again."
}

# ---------------------------------------------------------------------------
# SSH config
# ---------------------------------------------------------------------------

ensure_ssh_config() {
  local ssh_config="${HOME}/.ssh/config"
  local identity_display
  identity_display="$(path_for_display "$SSH_IDENTITY_FILE")"
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"

  if [[ ! -f "$ssh_config" ]]; then
    touch "$ssh_config"
    chmod 600 "$ssh_config"
  fi

  if grep -q "^Host ${SSH_HOST_ALIAS}$" "$ssh_config" 2>/dev/null; then
    # Update Port and IdentityFile in the existing block
    info "Updating SSH config entry '${SSH_HOST_ALIAS}' (port ${SSH_LOCAL_PORT})..."
    local tmp
    tmp="$(mktemp)"
    awk -v host="$SSH_HOST_ALIAS" -v port="$SSH_LOCAL_PORT" -v identity="$identity_display" '
      BEGIN { in_block=0 }
      /^Host / {
        if (in_block) in_block=0
        if ($2 == host) in_block=1
      }
      in_block && /^[[:space:]]*Port[[:space:]]/ { print "    Port " port; next }
      in_block && /^[[:space:]]*IdentityFile[[:space:]]/ { print "    IdentityFile " identity; next }
      { print }
    ' "$ssh_config" > "$tmp"
    mv "$tmp" "$ssh_config"
    chmod 600 "$ssh_config"
    return 0
  fi

  info "Creating SSH config entry '${SSH_HOST_ALIAS}' (port ${SSH_LOCAL_PORT})..."
  cat >> "$ssh_config" <<EOF

Host ${SSH_HOST_ALIAS}
    HostName localhost
    Port ${SSH_LOCAL_PORT}
    User cdsw
    IdentityFile ${identity_display}
    StrictHostKeyChecking no
    ServerAliveInterval 60
    ServerAliveCountMax 10
EOF
  chmod 600 "$ssh_config"
}

# ---------------------------------------------------------------------------
# Cursor connection instructions
# ---------------------------------------------------------------------------

print_cursor_instructions() {
  local identity_display
  identity_display="$(path_for_display "$SSH_IDENTITY_FILE")"
  cat <<EOF

===============================================================================
  SSH tunnel is active — keep this terminal open.
================================================================================

Sanity check (optional, in another terminal):
  ssh -i ${identity_display} -p ${SSH_LOCAL_PORT} cdsw@localhost

Connect in Cursor:
  1. Cmd+Shift+P (Mac) or Ctrl+Shift+P (Windows/Linux)
  2. "Remote-SSH: Connect to Host"
  3. Choose: ${SSH_HOST_ALIAS}
  4. File → Open Folder → /home/cdsw

When finished:
  Press Ctrl+C here to stop the SSH tunnel.
  The CAI session may still be running — stop it in the Workbench UI if needed.

EOF
}

# ---------------------------------------------------------------------------
# SSH tunnel (foreground — blocks until Ctrl+C)
# ---------------------------------------------------------------------------

start_ssh_tunnel() {
  local session_id="$1"
  local preferred_port="${SSH_LOCAL_PORT}"
  local bind_attempt=0
  local max_bind_attempts=10
  local tunnel_pid=""
  local tunnel_log=""

  while (( bind_attempt < max_bind_attempts )); do
    SSH_LOCAL_PORT="$(find_available_port "$preferred_port")"
    ensure_ssh_config

    info "Starting SSH endpoint (session=${session_id}, local port=${SSH_LOCAL_PORT})..."

    tunnel_log="$(mktemp)"
    cdswctl ssh-endpoint \
      -s "$session_id" \
      --project="$PROJECT_NAME" \
      --port="$SSH_LOCAL_PORT" 2>&1 | tee "$tunnel_log" &
    tunnel_pid=$!

    local waited=0
    local ready=false
    while (( waited < 60 )); do
      if grep -q "can't listen on port" "$tunnel_log"; then
        kill "$tunnel_pid" 2>/dev/null || true
        wait "$tunnel_pid" 2>/dev/null || true
        rm -f "$tunnel_log"
        preferred_port=$((SSH_LOCAL_PORT + 1))
        ((bind_attempt++))
        break
      fi

      if grep -qE "Forwarding local port|You can SSH to the session" "$tunnel_log"; then
        ready=true
        break
      fi

      if ! kill -0 "$tunnel_pid" 2>/dev/null; then
        cat "$tunnel_log" >&2
        rm -f "$tunnel_log"
        error "SSH endpoint exited before the tunnel was ready."
      fi

      sleep 1
      ((waited++))
    done

    if [[ "$ready" == "true" ]]; then
      break
    fi

    if (( waited >= 60 )); then
      kill "$tunnel_pid" 2>/dev/null || true
      wait "$tunnel_pid" 2>/dev/null || true
      cat "$tunnel_log" >&2
      rm -f "$tunnel_log"
      error "Timed out waiting for SSH endpoint on port ${SSH_LOCAL_PORT}."
    fi

    if (( bind_attempt >= max_bind_attempts )); then
      error "Could not start SSH endpoint after ${max_bind_attempts} port attempts."
    fi
  done

  print_cursor_instructions
  info "Press Ctrl+C to stop the tunnel."

  trap 'printf "\n" >&2; kill "$tunnel_pid" 2>/dev/null; wait "$tunnel_pid" 2>/dev/null; rm -f "$tunnel_log"; exit 0' INT TERM EXIT
  wait "$tunnel_pid"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  parse_args "$@"
  load_env
  check_prerequisites
  login_to_cai

  local runtime_id addon_id session_id

  if [[ "$TUNNEL_ONLY" == "true" ]]; then
    [[ -n "${SESSION_ID:-}" ]] \
      || error "--tunnel-only requires SESSION_ID in ${ENV_FILE}"
    session_id="$SESSION_ID"
    info "Tunnel-only mode: using session ${session_id}"
  else
    runtime_id="$(resolve_runtime_id)"
    addon_id="$(resolve_addon_id || true)"
    session_id="$(resolve_session_id "$runtime_id" "$addon_id")"
  fi

  start_ssh_tunnel "$session_id"
}

main "$@"
