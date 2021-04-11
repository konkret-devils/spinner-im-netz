#!/bin/bash

SPINNER_ROOT_DIR="/opt/spinner/"
BIGBLUE_ROOT_DIR="/opt/grandbleu/"

NGINX_CONF_DIR="${SPINNER_ROOT_DIR}nginx/"
TEMPLATES_DIR="${SPINNER_ROOT_DIR}templates/"

KONKRET_BIGBLUE_REPOSITORY_URL="https://github.com/konkret-devils/konkret-bigblue.git"
KONKRET_BIGBLUE_BRANCH="whereismymind-gl2.8"

INSTANCE_NAME="${1}"


#determine next available port numbers for new instance's containers (gl and db)
if [ $(find "${NGINX_CONF_DIR}" -name *.nginx -printf \"%f\\n\" | wc -l) -gt 0 ]; then

  MAX_USED_GL_PORT=$(ls -l "${NGINX_CONF_DIR}"*.nginx | tail -n 1 | awk '{print $NF}' | sed 's/^\([0-9][0-9][0-9][0-9][0-9]*\)_.*$/\1/g')
  NEXT_GL_PORT=$(expr "${MAX_USED_GL_PORT}" + 1)
  while [ $(netstat -ntlpu | cut -f4 | grep ":${NEXT_GL_PORT}" | wc -l) -gt 0 ]; do
    NEXT_GL_PORT=$(expr "${NEXT_GL_PORT}" + 1)
  done

  MAX_USED_DB_PORT=$(ls -l "${NGINX_CONF_DIR}"*.nginx | tail -n 1 | awk '{print $NF}' | sed 's/^[0-9][0-9][0-9][0-9][0-9]*_\([0-9][0-9][0-9][0-9][0-9]*\)_.*$/\1/g')
  NEXT_DB_PORT=$(expr "${MAX_USED_DB_PORT}" + 1)
  while [ $(netstat -ntlpu | cut -f4 | grep ":${NEXT_DB_PORT}" | wc -l) -gt 0 ]; do
    NEXT_DB_PORT=$(expr "${NEXT_DB_PORT}" + 1)
  done

  INSTANCE_PORT="${NEXT_GL_PORT}"
  INSTANCE_DB_PORT="${NEXT_DB_PORT}"

else

  INSTANCE_PORT=5014
  INSTANCE_DB_PORT=5447

fi

TARGET_DIR="${BIGBLUE_ROOT_DIR}${1}"

if [ ! -d "${TARGET_DIR}" ]; then

  cd "${BIGBLUE_ROOT_DIR}"
  git clone --branch "${KONKRET_BIGBLUE_BRANCH}" "${KONKRET_BIGBLUE_REPOSITORY_URL}" "${1}"

fi