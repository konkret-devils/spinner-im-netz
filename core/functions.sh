#!/bin/bash

function sleep_n_seconds () {
  if [ $# -ne 1 ]; then
    echo "sleep_n_seconds: Please verify the number of arguments passed. One argument (seconds: n <natural number>) is required." 1>&2
    exit 1
  fi

  local n_seconds="${1}"

  if [ ! "${n_seconds}" -gt 0 ]; then
    echo "sleep_n_seconds: argument passed (${n_seconds})is not a natural number."
    exit 2
  fi

  echo " ~ sleep for ${n_seconds} seconds, please stand by, as this is intented"
  sleep "${n_seconds}"
  echo " ~ okay. ${n_seconds} seconds have passed by..."
  exit 0
}


function to_template_variable_notation () {
  if [ $# -ne 1 ]; then
    echo "to_template_variable_notation: Please verify the number of arguments passed. One argument is required." 1>&2
    exit 1
  fi

  local input_string=$(echo "${1}" | sed "s/{{ *\([a-zA-Z0-9_\-][a-zA-Z0-9_\-]*\) *}}/\1/")

  echo "{{ ${input_string} }}"
}

function escape_slashes () {
  if [ $# -ne 1 ]; then
    echo "escape_slashes: Please verify the number of arguments passed. One argument is required." 1>&2
    exit 1
  fi

  local sedex_escape_slashes="s/\//\\\\\//g"
  local input_string="${1}"

  echo "${input_string}" | sed $sedex_escape_slashes
}

function template_replace_variable () {
  if [ $# -ne 3 ]; then
    echo "template_replace_variable: Please verify the number of arguments passed. Three arguments are required." 1>&2
    exit 1
  fi

  local file_name="${1}"
  local variable=$(to_template_variable_notation "${2}")
  local value=$(escape_slashes "${3}")

  if [ ! -f "${file_name}" ]; then
    echo "template_replace_variable: file ${file_name} not found" 1>&2
    exit 2
  fi

  sed -i "s/${variable}/${value}/g" $file_name
  exit 0
}

function template_reflective_replace_variables () {
  if [ ! $# -gt 1 ]; then
    echo "template_reflective_replace_variables: Please verify the number of arguments passed. At least two arguments are required." 1>&2
    exit 1
  fi

  local file_name="${1}"
  shift
  local variables=("$@")

  if [ ! -f "${file_name}" ]; then
    echo "template_reflective_replace_variables: file ${file_name} not found" 1>&2
    exit 2
  fi

  for variable in "${variables[@]}"
  do
    template_replace_variable "${file_name}" "${variable}" "${!variable}"
  done
  exit 0
}

function reflective_replace_variables () {
  local config_files=("$@")

  for config_file in "${config_files[@]}"
  do
    local config_file_name="${config_file}_FILE_NAME"
    local variables_to_replace="VARIABLES_${config_file}"

    template_reflective_replace_variables "${!config_file_name}" "${!variables_to_replace[@]}"
  done
  exit 0
}

function file_name_from_url () {
  if [ $# -ne 1 ]; then
    echo "file_name_from_url: Please verify the number of arguments passed. One argument is required." 1>&2
    exit 1
  fi

  local regex_filename_only="s/^.*\/\(.*\..*\)$/\1/g"

  local url="${1}"

  echo "${url}" | sed $regex_filename_only
}

function renew_assets () {
  if [ ! $# -gt 1 ]; then
    echo "renew_assets: Please verify the number of arguments passed. At least two arguments are required." 1>&2
    exit 1
  fi

  local instance_target_public_dir="${1}public/"
  shift
  local assets=("$@")

  for asset in "${assets[@]}"
  do
    local orig_url_var="${asset}_URL_ORIG"
    local orig_url="${!orig_url_var}"
    local asset_file_name=$(file_name_from_url "${orig_url}");
    local asset_file_name_local="${instance_target_public_dir}${asset_file_name}"

    rm -f "${asset_file_name_local}"

    echo " - wget -O ${asset_file_name_local} ${orig_url}"
    wget -q -O "${asset_file_name_local}" "${orig_url}"

    if [ ! -f "${asset_file_name_local}" ]; then
      echo "renew_assets: renewal of asset <${asset}> failed. File <${asset_file_name}> could not be downloaded from URL: ${orig_url}" 1>&2
    fi
  done
  exit 0
}

function template_fill_in_local_asset_urls () {
  if [ ! $# -gt 2 ]; then
    echo "template_fill_in_local_asset_urls: Please verify the number of arguments passed. At least three arguments are required." 1>&2
    exit 1
  fi

  local file_name="${1}"
  local instance_url="${2}"
  shift 2
  local assets=("$@")

  if [ ! -f "${file_name}" ]; then
    echo "template_fill_in_local_asset_urls: file ${file_name} not found" 1>&2
    exit 2
  fi

  for asset in "${assets[@]}"
  do
    local orig_url_var="${asset}_URL_ORIG"
    local orig_url="${!orig_url_var}"
    local asset_file_name=$(file_name_from_url "${orig_url}");

    local url_container="${instance_url}${asset_file_name}"
    local url_var_template="${asset}_URL"

    template_replace_variable "${file_name}" "${url_var_template}" "${url_container}"
  done
  exit 0
}

function copy_templates_to_config_files () {
  local config_files=("$@")

  for config_file in "${config_files[@]}"
  do
    local template_file_name="TEMPLATE_${config_file}_FILE_NAME"
    local target_config_file_name="${config_file}_FILE_NAME"

    cp "${!template_file_name}" "${!target_config_file_name}"
  done
  exit 0
}

function rebuild_restart_containers {
  if [ $# -ne 3 ]; then
    echo "rebuild_restart_containers: Please verify the number of arguments passed. Three arguments are required." 1>&2
    exit 1
  fi

  local instance_container_name="${1}"
  local instance_release_name="${2}"
  local instance_target_dir="${3}"

  cd "${instance_target_dir}"
  docker-compose down
  ./scripts/image_build.sh "${instance_container_name}" "${instance_release_name}"
  echo " - Bringing containers up ..."
  docker-compose up -d
  exit 0
}

function restart_containers {
  if [ $# -ne 1 ]; then
    echo "rebuild_restart_containers: Please verify the number of arguments passed. One argument is required." 1>&2
    exit 1
  fi

  local instance_target_dir="${3}"

  cd "${instance_target_dir}"
  docker-compose down
  sleep_n_seconds 10
  echo " - Bringing containers up ..."
  docker-compose up -d
  exit 0
}