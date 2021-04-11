#!/bin/bash

SPINNER_ROOT_DIR="/opt/konkret-spinner/"
SPINNER_TEMPLATES_DIR="${SPINNER_ROOT_DIR}templates/"
SPINNER_CONF_FILE="${SPINNER_ROOT_DIR}.env"

#parse & eval config file .env:

source "${SPINNER_CONF_FILE}"

#interrim ... should use getopt (not getopt*s*): <<

INSTANCE_NAME="${1}"

#...>>

INSTANCE_URL="https://${SPINNER_FQDN}/${INSTANCE_NAME}/"

#if first run...: <<

if [ ! -d "${NGINX_CONF_DIR}" ]; then
  mkdir -p "${NGINX_CONF_DIR}"
fi

#...>>

if [ ! -d "${BIGBLUE_ROOT_DIR}" ]; then
  mkdir -p "${BIGBLUE_ROOT_DIR}"
fi

#determine next available port numbers for new instance's containers (gl and db): <<

if [ $(find "${NGINX_CONF_DIR}" -name *.nginx.conf -printf "%f\n" | wc -l) -gt 0 ]; then

  if [ $(find "${NGINX_CONF_DIR}" -regex ".*\/[0-9][0-9][0-9][0-9][0-9]*_[0-9][0-9][0-9][0-9][0-9]*_${INSTANCE_NAME}\.nginx\.conf" | wc -l) -gt 0 ]; then

    CONF_FILE_NAME=$(find "${NGINX_CONF_DIR}" -regex ".*\/[0-9][0-9][0-9][0-9][0-9]*_[0-9][0-9][0-9][0-9][0-9]*_${INSTANCE_NAME}\.nginx\.conf" | tail -n 1)

    INSTANCE_PORT=$(echo "${CONF_FILE_NAME}" | sed 's/.*\/\([0-9][0-9][0-9][0-9][0-9]*\)_[0-9][0-9][0-9][0-9][0-9]*_.*$/\1/g')
    INSTANCE_DB_PORT=$(echo "${CONF_FILE_NAME}" | sed 's/.*\/[0-9][0-9][0-9][0-9][0-9]*_\([0-9][0-9][0-9][0-9][0-9]*\)_.*$/\1/g')

  else

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

  fi

else

  INSTANCE_PORT=5014
  INSTANCE_DB_PORT=5447

fi

# ...>>

#prerequisites for template processing: <<

INSTANCE_TARGET_DIR="${BIGBLUE_ROOT_DIR}${INSTANCE_NAME}/"
DOCKER_COMPOSE_YML_FILE_NAME="${INSTANCE_TARGET_DIR}docker-compose.yml"
ENV_FILE_NAME="${INSTANCE_TARGET_DIR}.env"
NGINX_CONF_FILE_NAME="${NGINX_CONF_DIR}${INSTANCE_PORT}_${INSTANCE_DB_PORT}_${INSTANCE_NAME}.nginx.conf"
VARIABLES_SCSS_FILE_NAME="${INSTANCE_TARGET_DIR}app/assets/stylesheets/utilities/_variables.scss";

#...>>

#clone / pull from repository: <<

if [ ! -d "${INSTANCE_TARGET_DIR}" ]; then

  cd "${BIGBLUE_ROOT_DIR}"
  git clone --branch "${KONKRET_BIGBLUE_BRANCH}" "${KONKRET_BIGBLUE_REPOSITORY_URL}" "${INSTANCE_NAME}"

fi

cd "${INSTANCE_TARGET_DIR}"
git pull -a

#...>>

#copy/renew assets from web locations:

INSTANCE_TARGET_PUBLIC_DIR="${INSTANCE_TARGET_DIR}public/"
if [ ! -d "${INSTANCE_TARGET_PUBLIC_DIR}" ]; then
  mkdir -p "${INSTANCE_TARGET_PUBLIC_DIR}"
fi

REGEX_FILENAME_ONLY="s/^.*\/\(.*\..*\)$/\1/g"

cd "${INSTANCE_TARGET_PUBLIC_DIR}"

HTML5_CLIENT_CSS_FILE_NAME=$(echo "${INSTANCE_HTML5_CLIENT_CSS_URL_ORIG}" | sed "${REGEX_FILENAME_ONLY}");
HTML5_CLIENT_LOGO_FILE_NAME=$(echo "${INSTANCE_HTML5_CLIENT_LOGO_IMAGE_URL_ORIG}" | sed "${REGEX_FILENAME_ONLY}");
BACKGROUND_IMAGE_LANDING_PAGE_FILE_NAME=$(echo "${INSTANCE_BACKGROUND_IMAGE_URL_LANDING_PAGE_ORIG}" | sed "${REGEX_FILENAME_ONLY}");
LOGO_FILE_NAME=$(echo "${INSTANCE_LOGO_IMAGE_URL_ORIG}" | sed "${REGEX_FILENAME_ONLY}");
LOGO_WITH_TEXT_FILE_NAME=$(echo "${INSTANCE_LOGO_WITH_TEXT_IMAGE_URL_ORIG}" | sed "${REGEX_FILENAME_ONLY}");
LOGO_EMAIL_FILE_NAME=$(echo "${INSTANCE_LOGO_EMAIL_IMAGE_URL_ORIG}" | sed "${REGEX_FILENAME_ONLY}");
DEFAULT_PRESENTATION_FILE_NAME=$(echo "${INSTANCE_DEFAULT_PRESENTATION_URL_ORIG}" | sed "${REGEX_FILENAME_ONLY}");

rm -f "./${HTML5_CLIENT_CSS_FILE_NAME}" \
      "./${HTML5_CLIENT_LOGO_FILE_NAME}" \
      "./${BACKGROUND_IMAGE_LANDING_PAGE_FILE_NAME}" \
      "./${LOGO_FILE_NAME}" \
      "./${LOGO_WITH_TEXT_FILE_NAME}" \
      "./${LOGO_EMAIL_FILE_NAME}" \
      "./${DEFAULT_PRESENTATION_FILE_NAME}"

wget -q "${INSTANCE_HTML5_CLIENT_CSS_URL_ORIG}"
wget -q "${INSTANCE_HTML5_CLIENT_LOGO_IMAGE_URL_ORIG}"
wget -q "${INSTANCE_BACKGROUND_IMAGE_URL_LANDING_PAGE_ORIG}"
wget -q "${INSTANCE_LOGO_IMAGE_URL_ORIG}"
wget -q "${INSTANCE_LOGO_WITH_TEXT_IMAGE_URL_ORIG}"
wget -q "${INSTANCE_LOGO_EMAIL_IMAGE_URL_ORIG}"
wget -q "${INSTANCE_DEFAULT_PRESENTATION_URL_ORIG}"

#generate config files from templates and the values we determined above: <<

INSTANCE_HTML5_CLIENT_CSS_URL="${INSTANCE_URL}${HTML5_CLIENT_CSS_FILE_NAME}"
INSTANCE_HTML5_CLIENT_LOGO_IMAGE_URL="${INSTANCE_URL}${HTML5_CLIENT_LOGO_FILE_NAME}"
INSTANCE_BACKGROUND_IMAGE_URL_LANDING_PAGE="${INSTANCE_URL}${BACKGROUND_IMAGE_LANDING_PAGE_FILE_NAME}"
INSTANCE_LOGO_IMAGE_URL="${INSTANCE_URL}${LOGO_FILE_NAME}"
INSTANCE_LOGO_WITH_TEXT_IMAGE_URL="${INSTANCE_URL}${LOGO_WITH_TEXT_FILE_NAME}"
INSTANCE_LOGO_EMAIL_IMAGE_URL="${INSTANCE_URL}${LOGO_EMAIL_FILE_NAME}"
INSTANCE_DEFAULT_PRESENTATION_URL="${INSTANCE_URL}${DEFAULT_PRESENTATION_FILE_NAME}"

INSTANCE_DB_PASSWORD=$(openssl rand -hex 16)

INSTANCE_MCU_PREFIX=$(openssl rand -hex 8)
INSTANCE_MCU_MOD_PREFIX=$(openssl rand -hex 8)

cat "${TEMPLATES_DIR}docker-compose.tmpl.yml" \
    | sed "s/{{ KONKRET_BIGBLUE_BRANCH }}/${KONKRET_BIGBLUE_BRANCH}/g" \
    | sed "s/{{ INSTANCE_NAME }}/${INSTANCE_NAME}/g" \
    | sed "s/{{ INSTANCE_PORT }}/${INSTANCE_PORT}/g" \
    | sed "s/{{ INSTANCE_DB_PORT }}/${INSTANCE_DB_PORT}/g" \
    | sed "s/{{ POSTGRES_RELEASE }}/${POSTGRES_RELEASE}/g" \
    | sed "s/{{ INSTANCE_DB_PASSWORD }}/${INSTANCE_DB_PASSWORD}/g" \
    > "${DOCKER_COMPOSE_YML_FILE_NAME}"

cat "${TEMPLATES_DIR}tmpl.env" \
    | sed "s/{{ INSTANCE_NAME }}/${INSTANCE_NAME}/g" \
    | sed "s/{{ INSTANCE_NAME_PREFIX }}/${INSTANCE_NAME_PREFIX}/g" \
    | sed "s/{{ SPINNER_FQDN }}/${SPINNER_FQDN}/g" \
    | sed "s/{{ SPINNER_BBB_FQDN }}/${SPINNER_BBB_FQDN}/g" \
    | sed "s/{{ SPINNER_BBB_SECRET }}/${SPINNER_BBB_SECRET}/g" \
    | sed "s/{{ INSTANCE_DB_PASSWORD }}/${INSTANCE_DB_PASSWORD}/g" \
    | sed "s/{{ INSTANCE_SMTP_SERVER }}/${INSTANCE_SMTP_SERVER}/g" \
    | sed "s/{{ INSTANCE_SMTP_PORT }}/${INSTANCE_SMTP_PORT}/g" \
    | sed "s/{{ INSTANCE_SMTP_DOMAIN }}/${INSTANCE_SMTP_DOMAIN}/g" \
    | sed "s/{{ INSTANCE_SMTP_USERNAME }}/${INSTANCE_SMTP_USERNAME}/g" \
    | sed "s/{{ INSTANCE_SMTP_PASSWORD }}/${INSTANCE_SMTP_PASSWORD}/g" \
    | sed "s/{{ INSTANCE_SMTP_STARTTLS_AUTO }}/${INSTANCE_SMTP_STARTTLS_AUTO}/g" \
    | sed "s/{{ INSTANCE_SMTP_SENDER_NAME }}/${INSTANCE_SMTP_SENDER_NAME}/g" \
    | sed "s/{{ INSTANCE_SMTP_SENDER_ADDRESS }}/${INSTANCE_SMTP_SENDER_ADDRESS}/g" \
    | sed "s/{{ INSTANCE_HTML5_CLIENT_CSS_URL }}/${INSTANCE_HTML5_CLIENT_CSS_URL}/g" \
    | sed "s/{{ INSTANCE_HTML5_CLIENT_LOGO_IMAGE_URL }}/${INSTANCE_HTML5_CLIENT_LOGO_IMAGE_URL}/g" \
    | sed "s/{{ SPINNER_NEELZ_EMAIL }}/${SPINNER_NEELZ_EMAIL}/g" \
    | sed "s/{{ SPINNER_NEELZ_EMAIL_PASSWORD }}/${SPINNER_NEELZ_EMAIL_PASSWORD}/g" \
    | sed "s/{{ SPINNER_ISHARE_BASE_URL }}/${SPINNER_ISHARE_BASE_URL}/g" \
    | sed "s/{{ INSTANCE_MCU_PREFIX }}/${INSTANCE_MCU_PREFIX}/g" \
    | sed "s/{{ INSTANCE_MCU_MOD_PREFIX }}/${INSTANCE_MCU_MOD_PREFIX}/g" \
    #TODO ergaenzen: INSTANCE_BACKGROUND_IMAGE_URL_LANDING_PAGE , INSTANCE_LOGO_IMAGE_URL ,
    #                (INSTANCE_LOGO_WITH_TEXT_IMAGE_URL ,) INSTANCE_LOGO_EMAIL_IMAGE_URL ,
    #                INSTANCE_DEFAULT_PRESENTATION_URL
    > "${ENV_FILE_NAME}"

cat "${TEMPLATES_DIR}tmpl.nginx.conf" \
    | sed "s/{{ INSTANCE_NAME }}/${INSTANCE_NAME}/g" \
    | sed "s/{{ INSTANCE_PORT }}/${INSTANCE_PORT}/g" \
    > "${NGINX_CONF_FILE_NAME}"

#TODO process _variables.tmpl.scss template

#...>>

#TODO ...