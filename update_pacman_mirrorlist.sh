#!/bin/bash
#
# Updates the pacman mirrorlist with a freshly generated one using only bash.

# Copyright 2025 Ash Hellwig <ahellwig.dev@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Global Variables
MIRRORLIST_TEMP="${HOME}/MIRRORLIST_TEMP"

MIRRORLIST_URL_RAW=(
  'https://archlinux.org/mirrorlist/'
  '?country=US'
  '&protocol=http'
  '&protocol=https'
  '&ip_version=4'
)

MIRRORLIST_URL="$(printf '%s' "${MIRRORLIST_URL_RAW[@]}")"

#######################################
# Checks the date of the downloaded mirror list compared to the current one.
# Outputs:
#   Usage of script and its options/arguments to stdout.
#######################################
function update_pacman_mirrorlist_help() {
  echo -e "$(cat <<END
\033[1;33mUsage:\033[0m update_pacman_mirrorlist.sh [-b|--backup] [-h|--help]
\033[1mMaintained By:\033[0m \033[2;32mAsh Hellwig\033[0m \033[4m<ahellwig.dev@gmail.com>\033[0m
\033[1mShort Option\tLong Option\tUse\033[0m
\033[1m------------------------------------------------------------\033[0m
-b\t\t--backup\tBackup existing mirrorlist
-h\t\t--help\t\tShow help and exit
END
)"
}

#######################################
# Generates a local timestamp.
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Timestamp in localtime.
#######################################
function generate_timestamp() {
  timedatectl | awk 'NR==1 {printf ("[%1s %s]", $4, $5)}'
}

#######################################
# Outputs a info message to STDOUT.
# Globals:
#   None
# Arguments:
#   Message to output, a string.
# Outputs:
#   Message to STDOUT in blue to indicate informational output.
#######################################
function info_msg() {
  timestamp=$(generate_timestamp)
  echo -e "\033[1;36m${timestamp} ${1}\033[0m"
}

#######################################
# Outputs a successful message to STDOUT.
# Globals:
#   None
# Arguments:
#   Message to output, a string.
# Outputs:
#   Message to STDOUT in green to indicate a success
#######################################
function success_msg() {
  timestamp=$(generate_timestamp)
  echo -e "\033[1;32m${timestamp} ${1}\033[0m"
}

#######################################
# Outputs a warning message to STDOUT.
# Globals:
#   None
# Arguments:
#   Message to output, a string.
# Outputs:
#   Message to STDOUT in yellow to indicate a warning
#######################################
function warning_msg() {
  timestamp=$(generate_timestamp)
  echo -e "\033[1;33m${timestamp} ${1}\033[0m"
}

#######################################
# Outputs an error message to STDOUT.
# Globals:
#   None
# Arguments:
#   Message to output, a string.
# Outputs:
#   Message to STDOUT in red to indicate a failure
#######################################
function error_msg() {
  timestamp=$(generate_timestamp)
  echo -e "\033[1;31m${timestamp} ${1}\033[0m"
}

#######################################
# Delete temporary directory for downloaded mirrorlist.
# Globals:
#   MIRRORLIST_TEMP
# Arguments:
#   None
# Returns:
#   0 if successful, non-zero on error.
#######################################
function clean_temp_dir() {
  if [[ -d "${MIRRORLIST_TEMP}" ]]; then
    rm -rf "${MIRRORLIST_TEMP}"
  fi

  if [[ ! -d "${MIRRORLIST_TEMP}" ]]; then
    success_msg "Successfully removed MIRRORLIST_TEMP at ${MIRRORLIST_TEMP}."
  else
    error_msg "Failed to delete MIRRORLIST_TEMP at ${MIRRORLIST_TEMP}."
    return 1
  fi
}

#######################################
# Create temporary directory for downloaded mirrorlist.
# Globals:
#   MIRRORLIST_TEMP
# Arguments:
#   None
# Returns:
#   0 if successful, non-zero on error.
#######################################
function create_temp_dir() {
  info_msg "Attempting to create temporary directory at ${MIRRORLIST_TEMP}."

  if [[ -d "${MIRRORLIST_TEMP}" ]]; then
    warning_msg "MIRRORLIST_TEMP already exists at ${MIRRORLIST_TEMP}. Removing."
    clean_temp_dir
    mkdir -p "${MIRRORLIST_TEMP}"
  else
    mkdir -p "${MIRRORLIST_TEMP}"
  fi

  if [[ -d "${MIRRORLIST_TEMP}" ]]; then
    success_msg "Successfully created MIRRORLIST_TEMP at ${MIRRORLIST_TEMP}."
  else
    warning_msg "Failed to create MIRRORLIST_TEMP at ${MIRRORLIST_TEMP}."
    return 1
  fi
}

#######################################
# Downloads the new mirrorlist file to `$MIRRORLIST_TEMP`.
# Globals:
#   MIRRORLIST_TEMP
#   MIRRORLIST_URL
# Arguments:
#   None
# Outputs:
#   Message indicating an updated mirrorlist to MIRRORLIST_TEMP was downloaded.
#######################################
function download_mirrorlist() {
  info_msg "Downloading new mirrorlist to ${MIRRORLIST_TEMP}."

  curl -s "$MIRRORLIST_URL" -o "${MIRRORLIST_TEMP}/mirrorlist"

  if [[ -f "${MIRRORLIST_TEMP}/mirrorlist" ]]; then
    success_msg "Successfully downloaded new mirrorlist file."
  else
    error_msg "Failed to download mirrorlist file."
    exit 1
  fi
}

#######################################
# Removes comments preceding the lines containing "server" in the mirrorlist.
# Globals:
#   MIRRORLIST_TEMP
# Arguments:
#   None
# Returns:
#   0 if successful, non-zero on error.
#######################################
function clean_mirrorlist_file() {
  info_msg "Cleaning mirrorlist file."

  awk \
    -i inplace \
    '{sub(/#Server/, "Server"); print}' \
    "${MIRRORLIST_TEMP}/mirrorlist"
}

#######################################
# Checks the date of specified mirrorlist.
# Globals:
#   MIRRORLIST_TEMP
# Arguments:
#   Path to mirrorlist file.
# Returns:
#   String containing the date the mirrorlist was last updated.
#######################################
function get_mirrorlist_date() {
  result=$(cat "${1}" | awk 'NR==3 {print $4}')
  echo "${result}"
}

#######################################
# Checks the date of the downloaded mirror list compared to the current one.
# Globals:
#   MIRRORLIST_TEMP
# Arguments:
#   None
# Returns:
#   "0" if the dates do NOT match and "1" if the dates DO match.
# Outputs:
#   Result of the date comparison.
#######################################
function check_mirrorlist_dates() {
  new_mirrorlist_date=$(get_mirrorlist_date "${MIRRORLIST_TEMP}/mirrorlist")

  info_msg "Date of new mirrorlist: $new_mirrorlist_date"

  if grep -qe "$new_mirrorlist_date" /etc/pacman.d/mirrorlist; then
    error_msg "Date is the same. Exiting."
    exit 1
  else
    success_msg "We have a newer mirrorlist downloaded. Continuing."
  fi
}

#######################################
# Removes and replaces the current mirrorlist with the new one, preserving
# the old mirrorlist as /etc/pacman.d/mirrorlist.bak.
# Globals:
#   MIRRORLIST_TEMP
# Arguments:
#   None
# Returns:
#   0 if successful, non-zero on error.
#######################################
function replace_mirrorlist_with_backup() {
  backup_info_msg_raw=(
    "Backup option was selected, "
    "moving current /etc/pacman.d/mirrorlist "
    "to /etc/pacman.d/mirrorlist.bak"
  )

  backup_info_msg="$(printf '%s' "${backup_info_msg_raw[@]}")"

  if [[ -f "/etc/pacman.d/mirrorlist.bak" ]] && [[ -f "/etc/pacman.d/mirrorlist" ]]; then
    info_msg "$backup_info_msg"
    warning_msg "Found previous backup. Removing."
    sudo rm -rf /etc/pacman.d/mirrorlist.bak
  fi

  sudo cp -r /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak

  if [[ -f "/etc/pacman.d/mirrorlist" ]]; then
    sudo rm -rf /etc/pacman.d/mirrorlist
  fi

  sudo cp -r "${MIRRORLIST_TEMP}/mirrorlist" /etc/pacman.d/mirrorlist

  if [[ -f "/etc/pacman.d/mirrorlist" ]]; then
    success_msg "Successfully updated mirrorlist!"
    exit 0
  else
    error_msg "Failed to update the mirrorlist."
    exit 1
  fi
}

#######################################
# Removes and replaces the current mirrorlist with the new one.
# Globals:
#   MIRRORLIST_TEMP
# Arguments:
#   None
# Returns:
#   0 if successful, non-zero on error.
#######################################
function replace_mirrorlist_without_backup() {
    backup_info_msg_raw=(
    "Backup option was NOT selected, "
    "removing current /etc/pacman.d/mirrorlist."
  )

  backup_info_msg="$(printf '%s' "${backup_info_msg_raw[@]}")"

  if [[ -f "/etc/pacman.d/mirrorlist" ]]; then
    sudo rm -rf /etc/pacman.d/mirrorlist
  fi

  sudo cp -r "${MIRRORLIST_TEMP}/mirrorlist" /etc/pacman.d/mirrorlist

  if [[ -f "/etc/pacman.d/mirrorlist" ]]; then
    success_msg "Successfully updated mirrorlist!"
    exit 0
  else
    error_msg "Failed to update the mirrorlist."
    exit 1
  fi
}

# Parse arguments
make_backup=false
key="$1"

case "${key}" in
  -b|--backup)
    make_backup=true
    ;;
  -h|--help)
    update_pacman_mirrorlist_help
    exit 0
    ;;
  ?)
    warning_msg "Argument not found!"
    update_pacman_mirrorlist_help
    exit 0
    ;;
  *)
    make_backup=false
esac

create_temp_dir

download_mirrorlist

clean_mirrorlist_file

check_mirrorlist_dates

if [[ "$make_backup" == true ]]; then
  info_msg "Creating a backup"
else
  info_msg "No backup being created"
fi

clean_temp_dir
