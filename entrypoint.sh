#!/usr/bin/env bash

set -e

# enable debug mode if desired
if [[ "${DEBUG}" == "true" ]]; then 
    set -x
fi

log() {
    LEVEL="${1}"
    TO_LOG="${2}"

    WHITE='\033[1;37m'
    YELLOW='\033[1;33m'
    RED='\033[1;31m'
    NO_COLOR='\033[0m'

    if [[ "${LEVEL}" == "warning" ]]; then
        LOG_LEVEL="${YELLOW}WARN${NO_COLOR}"
    elif [[ "${LEVEL}" == "error" ]]; then
        LOG_LEVEL="${RED}ERROR${NO_COLOR}"
    else
        LOG_LEVEL="${WHITE}INFO${NO_COLOR}"
        if [[ -z "${TO_LOG}" ]]; then
            TO_LOG="${1}"
        fi
    fi

    echo -e "[${LOG_LEVEL}] ${TO_LOG}"
}

ensure_mod() {
    FILE="${1}"
    MOD="${2}"
    U_ID="${3}"
    G_ID="${4}"

    chmod "${MOD}" "${FILE}"
    chown "${U_ID}":"${G_ID}" "${FILE}"
}

generate_passwd() {
    hexdump -e '"%02x"' -n 16 /dev/urandom
}

# ensure backward comaptibility for earlier versions of this image
if [[ -n "${KEYPAIR_LOGIN}" ]] && [[ "${KEYPAIR_LOGIN}" == "true" ]]; then
    ROOT_KEYPAIR_LOGIN_ENABLED="${KEYPAIR_LOGIN}"
fi
if [[ -n "${ROOT_PASSWORD}" ]]; then
    ROOT_LOGIN_UNLOCKED="true"
fi

# enable root login if keypair login is enabled
if [[ "${ROOT_KEYPAIR_LOGIN_ENABLED}" == "true" ]]; then
    ROOT_LOGIN_UNLOCKED="true"
fi

# initiate default sshd-config if there is none available
if [[ ! "$(ls -A /etc/ssh)" ]]; then
    cp -a "${CACHED_SSH_DIRECTORY}"/* /etc/ssh/.
fi
rm -rf "${CACHED_SSH_DIRECTORY}"

# generate host keys if not present
ssh-keygen -A 1>/dev/null

log "Applying configuration for 'root' user ..."

if [[ "${ROOT_LOGIN_UNLOCKED}" == "true" ]] ; then

    # generate random root password
    if [[ -z "${ROOT_PASSWORD}" ]]; then
        log "    generating random password for user 'root'"
        ROOT_PASSWORD="$(generate_passwd)"
    fi

    echo "root:${ROOT_PASSWORD}" | chpasswd &>/dev/null
    log "    password for user 'root' set"
    log "warning" "    user 'root' is now UNLOCKED"

    # set root login mode by password or keypair
    if [[ "${ROOT_KEYPAIR_LOGIN_ENABLED}" == "true" ]] && [[ -f "${HOME}/.ssh/authorized_keys" ]]; then
        sed -i "s/#PermitRootLogin.*/PermitRootLogin without-password/" /etc/ssh/sshd_config
        sed -i "s/#PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
        ensure_mod "${HOME}/.ssh/authorized_keys" "0600" "root" "root"
        log "    enabled login by keypair and disabled password-login for user 'root'"
    else
        sed -i "s/#PermitRootLogin.*/PermitRootLogin\ yes/" /etc/ssh/sshd_config
        log "    enabled login by password for user 'root'"
    fi

else

    sed -i "s/#PermitRootLogin.*/PermitRootLogin no/" /etc/ssh/sshd_config
    log "    disabled login for user 'root'"
    log "    user 'root' is now LOCKED"

fi

printf "\n"

log "Applying configuration for ${USERNAME} user ..."

USER_NAME="${USERNAME:-backintime}"

# Parse UID and GID from /passwd (mounted /etc/passwd from host)
if [[ -f "/passwd" ]]; then
    USER_INFO=$(grep "^${USER_NAME}:" /passwd)
    if [[ -n "${USER_INFO}" ]]; then
        USER_UID=$(echo "${USER_INFO}" | cut -d ':' -f 3)
        USER_GID=$(echo "${USER_INFO}" | cut -d ':' -f 4)
        log "    user: ${USER_NAME}, UID: ${USER_UID}, GID: ${USER_GID}"
    else
        log "error" "    user '${USER_NAME}' not found in /passwd!"
        exit 1
    fi
else
    log "error" "    /passwd not mounted or not accessible!"
    exit 1
fi

USER_GROUP="${USER_NAME}"
if getent group "${USER_GID}" &>/dev/null ; then 
    USER_GROUP="$(getent group "${USER_GID}" | cut -d ':' -f 1)"
    log "    desired GID is already present in system. Using the present group-name - GID: '${USER_GID}' GNAME: '${USER_GROUP}'"
else
    addgroup -g "${USER_GID}" "${USER_GROUP}"
fi

if getent passwd "${USER_NAME}" &>/dev/null ; then
    log "    user '${USER_NAME}' already exists in system - UID: '${USER_UID}' GID: '${USER_GID}' GNAME: '${USER_GROUP}'"
else
    adduser -s "${USER_LOGIN_SHELL}" -D -u "${USER_UID}" -G "${USER_GROUP}" "${USER_NAME}"
    log "    user '${USER_NAME}' created - UID: '${USER_UID}' GID: '${USER_GID}' GNAME: '${USER_GROUP}'"
fi

passwd -u "${USER_NAME}" &>/dev/null || true
mkdir -p "/home/${USER_NAME}/.ssh"

LOCAL_AUTHORIZED_KEYS="/home/${USER_NAME}/.ssh/authorized_keys"

# Check for public key in environment variable
if [[ -n "${PUBLIC_KEY}" ]]; then
    echo "${PUBLIC_KEY}" > "${LOCAL_AUTHORIZED_KEYS}"
    log "    set public key from environment variable"
else
    log "error" "    no PUBLIC_KEY environment variable provided"
fi

if [[ -e "${LOCAL_AUTHORIZED_KEYS}" ]]; then
    ensure_mod "${LOCAL_AUTHORIZED_KEYS}" "0600" "${USER_NAME}" "${USER_GID}"
    log "    set mod 0600 on ${LOCAL_AUTHORIZED_KEYS}"
    
    # Disable password authentication since we have authorized_keys
    sed -i "s/#PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
    log "    disabled password authentication for key-based login"
fi

# Make sure the access rights are correct
chmod 700 /etc/ssh -R

printf "\n"

echo ""

# do not detach (-D), log to stderr (-e), passthrough other arguments
exec /usr/sbin/sshd -D -e "$@"
