#!/bin/bash

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
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export SCRIPT_DIR

MIRRORLIST_TEMP="${HOME}/MIRRORLIST_TEMP"
export MIRRORLIST_TEMP

MIRRORLIST_URL_RAW=(
  'https://archlinux.org/mirrorlist/'
  '?country=US'
  '&protocol=http'
  '&protocol=https'
  '&ip_version=4'
)
export MIRRORLIST_URL_RAW

MIRRORLIST_URL="$(printf '%s' "${MIRRORLIST_URL_RAW[@]}")"
export MIRRORLIST_URL

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
    good "Successfully removed MIRRORLIST_TEMP at ${MIRRORLIST_TEMP}."
  else
    bad "Failed to delete MIRRORLIST_TEMP at ${MIRRORLIST_TEMP}."
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
  info "Attempting to create temporary directory at ${MIRRORLIST_TEMP}."

  if [[ -d "${MIRRORLIST_TEMP}" ]]; then
    warning "MIRRORLIST_TEMP already exists at ${MIRRORLIST_TEMP}. Removing."
    clean_temp_dir
    mkdir -p "${MIRRORLIST_TEMP}"
  else
    mkdir -p "${MIRRORLIST_TEMP}"
  fi

  if [[ -d "${MIRRORLIST_TEMP}" ]]; then
    good "Successfully created MIRRORLIST_TEMP at ${MIRRORLIST_TEMP}."
  else
    bad "Failed to create MIRRORLIST_TEMP at ${MIRRORLIST_TEMP}."
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
#   Updated mirrorlist to /etc/pacman.d/mirrorlist
#   OR
#   Message indicating that mirror list is already up-to-date to STDOUT
#######################################
function download_mirrorlist() {
  info "Downloading new mirrorlist to ${MIRRORLIST_TEMP}"

  curl "$MIRRORLIST_URL" -o "${MIRRORLIST_TEMP}/mirrorlist"
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
  # echo "${result}"
  echo "2024-10-15"
}

#######################################
# Checks the date of the downloaded mirror list compared to the current one.
# Globals:
#   MIRRORLIST_TEMP
# Arguments:
#   None
# Returns:
#   "0" if the dates do NOT match and "1" if the dates DO match.
#######################################
function check_mirrorlist_dates() {
  new_mirrorlist_date=$(get_mirrorlist_date "${MIRRORLIST_TEMP}/mirrorlist")

  info "Date of new mirrorlist: $new_mirrorlist_date"

  if grep -qe "$new_mirrorlist_date" /etc/pacman.d/mirrorlist; then
    info "Date is the same. Exiting."
    exit 1
  else
    info "We have a newer mirrorlist downloaded. Continuing."
  fi
}

create_temp_dir || ko

download_mirrorlist || ko

clean_mirrorlist_file || ko

check_mirrorlist_dates || ko

# Unset variables.
# unset MIRRORLIST_TEMP_DIR
# unset MIRRORLIST_URL_RAW
# unset MIRRORLIST_URL

# Unset functions.
# unfunction clean_temp_dir
# unfunction create_temp_dir
# unfunction download_mirrorlist
# unfunction get_mirrorlist_date
# unfunction check_mirrorlist_dates
