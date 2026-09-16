#!/command/with-contenv bashio
# shellcheck shell=bash
# shellcheck disable=SC2034

# user input variables
declare TARGET_DIR
declare KEEP_LOCAL
declare KEEP_REMOTE
declare TRIGGER_TIME
declare TRIGGER_DAYS
declare EXCLUDE_APPS
declare EXCLUDE_FOLDERS
declare BACKUP_NAME
declare BACKUP_PWD
declare SKIP_PRECHECK
declare HOST
declare HOST_MAC
declare WOL


# smbclient command strings
declare SMB
declare ALL_SHARES


# ------------------------------------------------------------------------------
# Read exclude_apps, honoring the legacy 'exclude_addons' key.
#
# Read-only on purpose: rewriting the options via API would resolve !secret
# references to plaintext (current Supervisor behavior).
#
# Returns the value on stdout
# ------------------------------------------------------------------------------
function read-exclude-apps {
    local value
    local options

    value=$(bashio::config 'exclude_apps')
    if [ -z "$value" ]; then
        options=$(bashio::addon.options)
        if bashio::jq.exists "${options}" '.exclude_addons'; then
            bashio::log.warning "Option 'exclude_addons' was renamed to 'exclude_apps'. Please update your configuration."
            value=$(echo "$options" | jq -r '.exclude_addons[]')
        fi
    fi

    echo "$value"
}

# ------------------------------------------------------------------------------
# Read and print config.
# ------------------------------------------------------------------------------
function get-config {
    local share
    local username
    local password
    local workgroup

    share=$(bashio::config 'share' | escape-input)
    username=$(bashio::config 'username' | escape-input)
    password=$(bashio::config 'password' | escape-input)
    bashio::config.exists 'workgroup' && workgroup=$(bashio::config 'workgroup' | escape-input) || workgroup=""

    TARGET_DIR=$(bashio::config 'target_dir')
    KEEP_LOCAL=$(bashio::config 'keep_local')
    KEEP_REMOTE=$(bashio::config 'keep_remote')
    TRIGGER_TIME=$(bashio::config 'trigger_time')
    TRIGGER_DAYS=$(bashio::config 'trigger_days')
    EXCLUDE_APPS=$(read-exclude-apps)
    EXCLUDE_FOLDERS=$(bashio::config 'exclude_folders')
    HOST=$(bashio::config 'host' | escape-input)

    bashio::config.exists 'backup_name' && BACKUP_NAME=$(bashio::config 'backup_name') || BACKUP_NAME=""
    bashio::config.exists 'backup_password' && BACKUP_PWD=$(bashio::config 'backup_password') || BACKUP_PWD=""
    bashio::config.true 'skip_precheck' && SKIP_PRECHECK=true || SKIP_PRECHECK=false
    bashio::config.exists 'host_mac' && HOST_MAC=$(bashio::config 'host_mac' | escape-input) || HOST_MAC=""
    bashio::config.true 'wol' && WOL=true || WOL=false

    if [ "$WOL" = true ] && [ -z "$HOST_MAC" ]; then
        bashio::log.fatal "WOL is enabled, but HOST_MAC is empty. Please provide a valid MAC address for Wake-on-LAN."
        return 1
    fi
    
    if [[ -n "$username" && -n "$password" ]]; then
        SMB="smbclient -U \"${username}\"%\"${password}\" \"//${HOST}/${share}\" 2>&1 -t 180"
        ALL_SHARES="smbclient -U \"${username}\"%\"${password}\" -L \"//${HOST}\" 2>&1"
    else
        SMB="smbclient -N \"//${HOST}/${share}\" 2>&1 -t 180"
        ALL_SHARES="smbclient -N -L \"//${HOST}\" 2>&1"
    fi

    # non-default workgroup?
    [ -n "$workgroup" ] && SMB="${SMB} -W \"${workgroup}\""
    [ -n "$workgroup" ] && ALL_SHARES="${ALL_SHARES} -W \"${workgroup}\""

    # legacy SMB protocols allowed?
    bashio::config.true 'compatibility_mode' && SMB="${SMB} --option=\"client min protocol\"=\"NT1\""
    bashio::config.true 'compatibility_mode' && ALL_SHARES="${ALL_SHARES} --option=\"client min protocol\"=\"NT1\""

    bashio::log.info "---------------------------------------------------"
    bashio::log.info "Host/Share: ${HOST}/${share}"
    [[ -n "$HOST_MAC" ]] && bashio::log.info "Host MAC: ${HOST_MAC}"
    bashio::log.info "Target directory: ${TARGET_DIR}"
    bashio::log.info "Keep local/remote: ${KEEP_LOCAL}/${KEEP_REMOTE}"
    bashio::log.info "Trigger time: ${TRIGGER_TIME}"
    [[ "$TRIGGER_TIME" != "manual" ]] && bashio::log.info "Trigger days: $(echo "$TRIGGER_DAYS" | xargs)"
    bashio::log.info "---------------------------------------------------"

    return 0
}

# ------------------------------------------------------------------------------
# Escape input given by the user.
#
# Returns the escaped string on stdout
# ------------------------------------------------------------------------------
function escape-input {
    local input
    read -r input

    # escape the evil dollar sign
    input=${input//$/\\$}

    echo "$input"
}

# ------------------------------------------------------------------------------
# Overwrite the backup parameters.
#
# Arguments
#  $1 The json input string
# ------------------------------------------------------------------------------
function overwrite-params {
    local input="$1"
    local addons
    local folders
    local name
    local password

    # legacy 'exclude_addons' key still accepted for existing automations
    addons=$(echo "$input" | jq '(.exclude_apps // .exclude_addons)[]' 2>/dev/null)
    [[ "$addons" != null  ]] && EXCLUDE_APPS="$addons"

    folders=$(echo "$input" | jq '.exclude_folders[]' 2>/dev/null)
    [[ "$folders" != null  ]] && EXCLUDE_FOLDERS="$folders"

    name=$(echo "$input" | jq -r '.backup_name')
    [[ "$name" != null  ]] && BACKUP_NAME="$name"

    password=$(echo "$input" | jq -r '.backup_password')
    [[ "$password" != null  ]] && BACKUP_PWD="$password"

    return 0
}

# ------------------------------------------------------------------------------
# Restore the original backup parameters.
# ------------------------------------------------------------------------------
function restore-params {
    EXCLUDE_APPS=$(read-exclude-apps)
    EXCLUDE_FOLDERS=$(bashio::config 'exclude_folders')
    bashio::config.exists 'backup_name' && BACKUP_NAME=$(bashio::config 'backup_name') || BACKUP_NAME=""
    bashio::config.exists 'backup_password' && BACKUP_PWD=$(bashio::config 'backup_password') || BACKUP_PWD=""

    return 0
}
