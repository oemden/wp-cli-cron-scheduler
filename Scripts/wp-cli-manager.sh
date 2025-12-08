#!/bin/bash

# wp-cli-manager.sh
# Unified WordPress management via wp-cli
# - Cron jobs (bypass Cloudflare WAF anti-bot rules)
# - Plugin/Theme updates
version="v0.4.0"

#
# Usage: wp-cli-manager.sh [-w path | -W alias] [-c|-C] [-p|-P] [-u|-U] [-t|-T] [-o|-O] [-a|-A]
#   WP Path (mutually exclusive):
#     -w  Explicit WordPress path (e.g., -w /home/user/site1)
#     -W  Alias from ~/.wp-cli-manager-sites.env (e.g., -W SITE1)
#     (default: current directory if neither specified)
#   Cron:
#     -c  Run pending cron jobs (time-based)
#     -C  Run ALL cron jobs (ignore schedule)
#   Plugins:
#     -p  Active plugins only
#     -P  All plugin statuses (active + inactive)
#     -u  Auto-update ON only
#     -U  All auto-update statuses (on + off)
#   Themes:
#     -t  Active themes only
#     -T  All theme statuses (active + inactive)
#     -o  Auto-update ON only
#     -O  All auto-update statuses (on + off)
#   Shortcuts:
#     -a  Safe mode: -c -p -u -t -o
#     -A  Aggressive mode: -C -P -U -T -O

# n8n fails to find wp, so let's help it:
source $HOME/.bash_profile 2>/dev/null || true

#############################################################################
# WP Path Resolution and Configuration
#############################################################################

# Initialize path flags
WP_PATH_EXPLICIT=""
WP_PATH_ALIAS=""

# Parse wp path options first (need to extract -w and -W before other flags)
while getopts ":w:W:cCpPuUtToOaA" opt; do
  case $opt in
    w) WP_PATH_EXPLICIT="$OPTARG" ;;
    W) WP_PATH_ALIAS="$OPTARG" ;;
    \?) ;; # Ignore unknown options for now
  esac
done
OPTIND=1  # Reset for second parse

# Validate mutually exclusive flags
if [ -n "$WP_PATH_EXPLICIT" ] && [ -n "$WP_PATH_ALIAS" ]; then
  echo "" >&2
  echo "ERROR: Flags -w and -W are mutually exclusive!" >&2
  echo "Use either -w (explicit path) OR -W (alias), not both." >&2
  echo "" >&2
  exit 1
fi

# Resolve wp_path
if [ -n "$WP_PATH_EXPLICIT" ]; then
  # Mode 1: Explicit path via -w
  wp_path="$WP_PATH_EXPLICIT"
  echo "[INFO] Using explicit WordPress path: $wp_path"

elif [ -n "$WP_PATH_ALIAS" ]; then
  # Mode 2: Alias from sites file via -W
  SITES_FILE="${HOME}/.wp-cli-manager-sites.env"

  if [ ! -f "$SITES_FILE" ]; then
    echo "" >&2
    echo "ERROR: Sites file not found: $SITES_FILE" >&2
    echo "Create it with site aliases, e.g.:" >&2
    echo "  SITE1=/home/user/wordpress1" >&2
    echo "  SITE2=/home/user/wordpress2" >&2
    echo "" >&2
    exit 1
  fi

  # Load alias from sites file
  wp_path=$(grep "^${WP_PATH_ALIAS}=" "$SITES_FILE" | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

  if [ -z "$wp_path" ]; then
    echo "" >&2
    echo "ERROR: Alias '$WP_PATH_ALIAS' not found in $SITES_FILE" >&2
    echo "" >&2
    exit 1
  fi

  echo "[INFO] Using aliased WordPress path: $WP_PATH_ALIAS -> $wp_path"

else
  # Mode 3: Default to current directory
  wp_path="$PWD"
  echo "[INFO] Using current directory as WordPress path: $wp_path"
fi

# Validate wp_path exists
if [ ! -d "$wp_path" ]; then
  echo "" >&2
  echo "ERROR: WordPress path does not exist: $wp_path" >&2
  echo "" >&2
  exit 1
fi

# Load site-specific .env file from WordPress directory
load_env_file() {
  local env_file="$1"

  if [ ! -f "$env_file" ]; then
    return 0
  fi

  echo "[INFO] Loading site configuration from: $env_file"

  # Read .env file line by line
  while IFS= read -r line || [ -n "$line" ]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$line" ]] && continue

    # Remove leading/trailing whitespace
    line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Skip if not key=value format
    [[ ! "$line" =~ ^[a-zA-Z_][a-zA-Z0-9_]*= ]] && continue

    # Split on first =
    key="${line%%=*}"
    value="${line#*=}"

    # Remove quotes from value if present
    value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

    # Always load from .env (overwrites environment)
    export "$key=$value"
    echo "[INFO]   $key=$value"
  done < "$env_file"
}

# Load configuration from WordPress directory
ENV_FILE="${wp_path}/.wp-cli-manager.env"
if [ -f "$ENV_FILE" ]; then
  load_env_file "$ENV_FILE"
fi

# Set optional variables with defaults
: ${plugin_mgmt:="true"}
: ${theme_mgmt:="true"}
: ${run_all_crons:="false"}

# Move to WordPress directory
cd "$wp_path" || exit 1

# CLI Flags
FLAG_CRON_PENDING=false
FLAG_CRON_ALL=false
FLAG_PLUGIN_ACTIVE=false
FLAG_PLUGIN_ALL_STATUS=false
FLAG_PLUGIN_AUTOUPDATE=false
FLAG_PLUGIN_ALL_AUTOUPDATE=false
FLAG_THEME_ACTIVE=false
FLAG_THEME_ALL_STATUS=false
FLAG_THEME_AUTOUPDATE=false
FLAG_THEME_ALL_AUTOUPDATE=false

# Parse action options (second pass after wp path resolution)
while getopts ":w:W:cCpPuUtToOaA" opt; do
  case $opt in
    w|W) ;; # Already handled in first pass
    c) FLAG_CRON_PENDING=true ;;
    C) FLAG_CRON_ALL=true ;;
    p) FLAG_PLUGIN_ACTIVE=true ;;
    P) FLAG_PLUGIN_ALL_STATUS=true ;;
    u) FLAG_PLUGIN_AUTOUPDATE=true ;;
    U) FLAG_PLUGIN_ALL_AUTOUPDATE=true ;;
    t) FLAG_THEME_ACTIVE=true ;;
    T) FLAG_THEME_ALL_STATUS=true ;;
    o) FLAG_THEME_AUTOUPDATE=true ;;
    O) FLAG_THEME_ALL_AUTOUPDATE=true ;;
    a) # Safe mode shortcut
       FLAG_CRON_PENDING=true
       FLAG_PLUGIN_ACTIVE=true
       FLAG_PLUGIN_AUTOUPDATE=true
       FLAG_THEME_ACTIVE=true
       FLAG_THEME_AUTOUPDATE=true
       ;;
    A) # Aggressive mode shortcut
       FLAG_CRON_ALL=true
       FLAG_PLUGIN_ALL_STATUS=true
       FLAG_PLUGIN_ALL_AUTOUPDATE=true
       FLAG_THEME_ALL_STATUS=true
       FLAG_THEME_ALL_AUTOUPDATE=true
       ;;
    \?) echo "ERROR: Unknown option -$OPTARG" >&2; exit 1 ;;
    :) echo "ERROR: Option -$OPTARG requires an argument" >&2; exit 1 ;;
  esac
done

#############################################################################
# Functions
#############################################################################

run_all_cron_jobs() {
  echo "=== Running ALL cron jobs ==="
  wp cron event list --format=json | grep -o '"hook":"[^"]*"' | cut -d'"' -f4 | while read hook; do
    echo "Running: $hook"
    wp cron event run "$hook"
  done
}

run_pending_cron_jobs() {
  echo "=== Running pending cron jobs ==="
  CURRENT_EPOCH=$(date +%s)

  wp cron event list --format=json | grep -o '"hook":"[^"]*","next_run_gmt":"[^"]*"' | while read line; do
    HOOK=$(echo "$line" | grep -o '"hook":"[^"]*"' | cut -d'"' -f4)
    NEXT_RUN=$(echo "$line" | grep -o '"next_run_gmt":"[^"]*"' | cut -d'"' -f4)
    NEXT_EPOCH=$(date -d "${NEXT_RUN}" +%s 2>/dev/null)

    if [ "${NEXT_EPOCH}" -le "${CURRENT_EPOCH}" ]; then
      echo "Running: $HOOK (due: ${NEXT_RUN})"
      wp cron event run "${HOOK}"
    else
      echo "Skipping: $HOOK (next due: ${NEXT_RUN})"
    fi
  done
}

update_wp_component() {
  local component=$1        # "plugin" or "theme"
  local active_only=$2      # true = active only, false = all statuses
  local autoupdate_only=$3  # true = auto_update=on only, false = all

  echo "=== Updating ${component}s (active_only=$active_only, autoupdate_only=$autoupdate_only) ==="

  # Get component list as JSON and parse without jq
  wp ${component} list --format=json | grep -o '"name":"[^"]*","status":"[^"]*","update":"[^"]*"[^}]*"auto_update":"[^"]*"' | while read line; do
    # Extract fields
    NAME=$(echo "$line" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
    STATUS=$(echo "$line" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    UPDATE=$(echo "$line" | grep -o '"update":"[^"]*"' | cut -d'"' -f4)
    AUTO_UPDATE=$(echo "$line" | grep -o '"auto_update":"[^"]*"' | cut -d'"' -f4)

    # Skip if no update available
    if [ "$UPDATE" != "available" ]; then
      continue
    fi

    # Filter by active status
    if [ "$active_only" = true ] && [ "$STATUS" != "active" ]; then
      echo "Skipping $NAME: not active (status: $STATUS)"
      continue
    fi

    # Filter by auto_update status
    if [ "$autoupdate_only" = true ] && [ "$AUTO_UPDATE" != "on" ]; then
      echo "Skipping $NAME: auto_update not enabled (auto_update: $AUTO_UPDATE)"
      continue
    fi

    # Perform update
    echo "[${component^^}_UPDATE] Updating: $NAME (status: $STATUS, auto_update: $AUTO_UPDATE)"
    wp ${component} update "$NAME"

    if [ $? -eq 0 ]; then
      echo "[${component^^}_UPDATED] Success: $NAME"
    else
      echo "[${component^^}_ERROR] Failed: $NAME"
    fi
  done
}

#############################################################################
# Main Execution
#############################################################################

# Default behavior (no flags): safe mode (-a)
if [ "$FLAG_CRON_PENDING" = false ] && [ "$FLAG_CRON_ALL" = false ] && \
   [ "$FLAG_PLUGIN_ACTIVE" = false ] && [ "$FLAG_PLUGIN_ALL_STATUS" = false ] && \
   [ "$FLAG_PLUGIN_AUTOUPDATE" = false ] && [ "$FLAG_PLUGIN_ALL_AUTOUPDATE" = false ] && \
   [ "$FLAG_THEME_ACTIVE" = false ] && [ "$FLAG_THEME_ALL_STATUS" = false ] && \
   [ "$FLAG_THEME_AUTOUPDATE" = false ] && [ "$FLAG_THEME_ALL_AUTOUPDATE" = false ]; then
  echo "=== Default mode: -a (safe mode) ==="
  FLAG_CRON_PENDING=true
  FLAG_PLUGIN_ACTIVE=true
  FLAG_PLUGIN_AUTOUPDATE=true
  FLAG_THEME_ACTIVE=true
  FLAG_THEME_AUTOUPDATE=true
fi

# Execute cron jobs
if [ "$FLAG_CRON_ALL" = true ]; then
  run_all_cron_jobs
fi

if [ "$FLAG_CRON_PENDING" = true ]; then
  run_pending_cron_jobs
fi

# Execute plugin updates (need both status AND autoupdate flags)
if [ "$FLAG_PLUGIN_ACTIVE" = true ] || [ "$FLAG_PLUGIN_ALL_STATUS" = true ]; then
  if [ "$FLAG_PLUGIN_AUTOUPDATE" = true ] || [ "$FLAG_PLUGIN_ALL_AUTOUPDATE" = true ]; then
    # Determine parameters
    PLUGIN_ACTIVE_ONLY=false
    if [ "$FLAG_PLUGIN_ACTIVE" = true ]; then
      PLUGIN_ACTIVE_ONLY=true
    fi

    PLUGIN_AUTOUPDATE_ONLY=false
    if [ "$FLAG_PLUGIN_AUTOUPDATE" = true ]; then
      PLUGIN_AUTOUPDATE_ONLY=true
    fi

    update_wp_component "plugin" "$PLUGIN_ACTIVE_ONLY" "$PLUGIN_AUTOUPDATE_ONLY"
  fi
fi

# Execute theme updates (need both status AND autoupdate flags)
if [ "$FLAG_THEME_ACTIVE" = true ] || [ "$FLAG_THEME_ALL_STATUS" = true ]; then
  if [ "$FLAG_THEME_AUTOUPDATE" = true ] || [ "$FLAG_THEME_ALL_AUTOUPDATE" = true ]; then
    # Determine parameters
    THEME_ACTIVE_ONLY=false
    if [ "$FLAG_THEME_ACTIVE" = true ]; then
      THEME_ACTIVE_ONLY=true
    fi

    THEME_AUTOUPDATE_ONLY=false
    if [ "$FLAG_THEME_AUTOUPDATE" = true ]; then
      THEME_AUTOUPDATE_ONLY=true
    fi

    update_wp_component "theme" "$THEME_ACTIVE_ONLY" "$THEME_AUTOUPDATE_ONLY"
  fi
fi

echo ""
echo "=== wp-cli-manager.sh version ${version} completed ==="
