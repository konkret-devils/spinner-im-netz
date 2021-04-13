#!/bin/bash

SPINNER_ROOT_DIR="/opt/konkret-spinner/"
SPINNER_TEMPLATES_DIR="${SPINNER_ROOT_DIR}templates/"
SPINNER_CONF_FILE="${SPINNER_ROOT_DIR}.env"

echo "*** konkret spinner ***"
echo ""

#parse & eval config file .env: <<

echo " - reading .env file"
source "${SPINNER_CONF_FILE}"

#...>

#interrim ... should use getopt (not getopt*s*), also for additional variables,
#or initializer config file should be source'd on top,
#shadowing the default values in .env config file: <<

INSTANCE_NAME="${1}"
ADMIN_NAME="${2}"
ADMIN_EMAIL="${3}"
ADMIN_PASSWORD="${4}"
WITH_NEELZ_LAYER_SUPPORT="${5}"
INSTANCE_MCU_PREFIX="${6}"

#...>>

INSTANCE_URL="https://${SPINNER_FQDN}/${INSTANCE_NAME}/"
echo " ~ instance URL -> ${INSTANCE_URL}"

#on first run, spinner base directories will probably need to be created...: <<

if [ ! -d "${NGINX_CONF_DIR}" ]; then
  mkdir -p "${NGINX_CONF_DIR}"
  echo " - created nginx conf directory for spinner (Is this your first run...?) -> ${NGINX_CONF_DIR}"
fi

if [ ! -d "${BIGBLUE_ROOT_DIR}" ]; then
  mkdir -p "${BIGBLUE_ROOT_DIR}"
  echo " - created root directory for spinner's bigBLUE instance containers (Is this your first run...?) -> ${BIGBLUE_ROOT_DIR}"
fi

#...>>

#determine next available port numbers for new instance's containers (gl and db): <<

echo " - determine (next) available port numbers for new instance's containers"
if [ $(find "${NGINX_CONF_DIR}" -name *.nginx.conf -printf "%f\n" | wc -l) -gt 0 ]; then

  if [ $(find "${NGINX_CONF_DIR}" -regex ".*\/[0-9][0-9][0-9][0-9][0-9]*_[0-9][0-9][0-9][0-9][0-9]*_${INSTANCE_NAME}\.nginx\.conf" | wc -l) -gt 0 ]; then

    CONF_FILE_NAME=$(find "${NGINX_CONF_DIR}" -regex ".*\/[0-9][0-9][0-9][0-9][0-9]*_[0-9][0-9][0-9][0-9][0-9]*_${INSTANCE_NAME}\.nginx\.conf" | tail -n 1)

    INSTANCE_PORT=$(echo "${CONF_FILE_NAME}" | sed 's/.*\/\([0-9][0-9][0-9][0-9][0-9]*\)_[0-9][0-9][0-9][0-9][0-9]*_.*$/\1/g')
    INSTANCE_DB_PORT=$(echo "${CONF_FILE_NAME}" | sed 's/.*\/[0-9][0-9][0-9][0-9][0-9]*_\([0-9][0-9][0-9][0-9][0-9]*\)_.*$/\1/g')

    echo " ~ continue using the previous ports (instance already exists and will merely be rebuilt)"

  else

    MAX_USED_GL_PORT=$(ls -l "${NGINX_CONF_DIR}*.nginx.conf" | tail -n 1 | awk '{print $NF}' | sed 's/^\([0-9][0-9][0-9][0-9][0-9]*\)_.*$/\1/g')
    NEXT_GL_PORT=$(expr "${MAX_USED_GL_PORT}" + 1)
    while [ $(netstat -ntlpu | cut -f4 | grep ":${NEXT_GL_PORT}" | wc -l) -gt 0 ]; do
      NEXT_GL_PORT=$(expr "${NEXT_GL_PORT}" + 1)
    done

    MAX_USED_DB_PORT=$(ls -l "${NGINX_CONF_DIR}*.nginx.conf" | tail -n 1 | awk '{print $NF}' | sed 's/^[0-9][0-9][0-9][0-9][0-9]*_\([0-9][0-9][0-9][0-9][0-9]*\)_.*$/\1/g')
    NEXT_DB_PORT=$(expr "${MAX_USED_DB_PORT}" + 1)
    while [ $(netstat -ntlpu | cut -f4 | grep ":${NEXT_DB_PORT}" | wc -l) -gt 0 ]; do
      NEXT_DB_PORT=$(expr "${NEXT_DB_PORT}" + 1)
    done

    INSTANCE_PORT="${NEXT_GL_PORT}"
    INSTANCE_DB_PORT="${NEXT_DB_PORT}"

    echo " ~ allocated a pair of free ports for this instance..."

  fi

else

  INSTANCE_PORT=5014
  INSTANCE_DB_PORT=5447

fi
echo " ~ :: mainContainer:PORT=${INSTANCE_PORT} / postgresDBContainer:PORT=${INSTANCE_DB_PORT}"

# ...>>

#prerequisites for template processing: <<

TEMPLATE_DOCKER_COMPOSE_YML_FILE_NAME="${SPINNER_TEMPLATES_DIR}docker-compose.tmpl.yml"
TEMPLATE_ENV_FILE_NAME="${SPINNER_TEMPLATES_DIR}tmpl.env"
TEMPLATE_VARIABLES_SCSS_FILE_NAME="${SPINNER_TEMPLATES_DIR}assets/stylesheets/_variables.tmpl.scss"
TEMPLATE_NGINX_CONF_FILE_NAME="${SPINNER_TEMPLATES_DIR}tmpl.nginx.conf"

INSTANCE_TARGET_DIR="${BIGBLUE_ROOT_DIR}${INSTANCE_NAME}/"
DOCKER_COMPOSE_YML_FILE_NAME="${INSTANCE_TARGET_DIR}docker-compose.yml"
ENV_FILE_NAME="${INSTANCE_TARGET_DIR}.env"
SAMPLE_ENV_FILE_NAME="${INSTANCE_TARGET_DIR}sample.env"
NGINX_CONF_FILE_NAME="${NGINX_CONF_DIR}${INSTANCE_PORT}_${INSTANCE_DB_PORT}_${INSTANCE_NAME}.nginx.conf"
VARIABLES_SCSS_FILE_NAME="${INSTANCE_TARGET_DIR}app/assets/stylesheets/utilities/_variables.scss";

# sed expression for escaping slashes
SEDEX_ESCAPE_SLASHES="s/\//\\\\\//g"

# assembling - functions:

function assemble_docker_compose_yml_file {

  echo " - assembling ${DOCKER_COMPOSE_YML_FILE_NAME}"

  cat "${TEMPLATE_DOCKER_COMPOSE_YML_FILE_NAME}" \
      | sed "s/{{ INSTANCE_CONTAINER_NAME }}/${INSTANCE_CONTAINER_NAME}/g" \
      | sed "s/{{ INSTANCE_RELEASE_NAME }}/${INSTANCE_RELEASE_NAME}/g" \
      | sed "s/{{ INSTANCE_PORT }}/${INSTANCE_PORT}/g" \
      | sed "s/{{ INSTANCE_DB_PORT }}/${INSTANCE_DB_PORT}/g" \
      | sed "s/{{ POSTGRES_RELEASE }}/${POSTGRES_RELEASE}/g" \
      | sed "s/{{ INSTANCE_DB_PASSWORD }}/${INSTANCE_DB_PASSWORD}/g" \
      > "${DOCKER_COMPOSE_YML_FILE_NAME}"

}

function assemble_env_file {

  local secret_key_base=$(echo "${INSTANCE_SECRET_KEY_BASE}" | sed $SEDEX_ESCAPE_SLASHES)
  local instance_name=$(echo "${INSTANCE_NAME}" | sed $SEDEX_ESCAPE_SLASHES)
  local instance_name_prefix=$(echo "${INSTANCE_NAME_PREFIX}" | sed $SEDEX_ESCAPE_SLASHES)
  local bbb_secret=$(echo "${SPINNER_BBB_SECRET}" | sed $SEDEX_ESCAPE_SLASHES)
  local smtp_password=$(echo "${INSTANCE_SMTP_PASSWORD}" | sed $SEDEX_ESCAPE_SLASHES)
  local smtp_sender_name=$(echo "${INSTANCE_SMTP_SENDER_NAME}" | sed $SEDEX_ESCAPE_SLASHES)
  local neelz_email_password=$(echo "${SPINNER_NEELZ_EMAIL_PASSWORD}" | sed $SEDEX_ESCAPE_SLASHES)
  local ishare_base_url=$(echo "${SPINNER_ISHARE_BASE_URL}" | sed $SEDEX_ESCAPE_SLASHES)
  local mcu_prefix=$(echo "${INSTANCE_MCU_PREFIX}" | sed $SEDEX_ESCAPE_SLASHES)
  local mcu_mod_prefix=$(echo "${INSTANCE_MCU_MOD_PREFIX}" | sed $SEDEX_ESCAPE_SLASHES)

  echo " - assembling ${ENV_FILE_NAME}"

  cat "${TEMPLATE_ENV_FILE_NAME}" \
      | sed "s/{{ INSTANCE_SECRET_KEY_BASE }}/${secret_key_base}/g" \
      | sed "s/{{ INSTANCE_NAME }}/${instance_name}/g" \
      | sed "s/{{ INSTANCE_NAME_PREFIX }}/${instance_name_prefix}/g" \
      | sed "s/{{ SPINNER_FQDN }}/${SPINNER_FQDN}/g" \
      | sed "s/{{ SPINNER_BBB_FQDN }}/${SPINNER_BBB_FQDN}/g" \
      | sed "s/{{ SPINNER_BBB_SECRET }}/${bbb_secret}/g" \
      | sed "s/{{ INSTANCE_DB_PASSWORD }}/${INSTANCE_DB_PASSWORD}/g" \
      | sed "s/{{ INSTANCE_SMTP_SERVER }}/${INSTANCE_SMTP_SERVER}/g" \
      | sed "s/{{ INSTANCE_SMTP_PORT }}/${INSTANCE_SMTP_PORT}/g" \
      | sed "s/{{ INSTANCE_SMTP_DOMAIN }}/${INSTANCE_SMTP_DOMAIN}/g" \
      | sed "s/{{ INSTANCE_SMTP_USERNAME }}/${INSTANCE_SMTP_USERNAME}/g" \
      | sed "s/{{ INSTANCE_SMTP_PASSWORD }}/${smtp_password}/g" \
      | sed "s/{{ INSTANCE_SMTP_STARTTLS_AUTO }}/${INSTANCE_SMTP_STARTTLS_AUTO}/g" \
      | sed "s/{{ INSTANCE_SMTP_SENDER_NAME }}/${smtp_sender_name}/g" \
      | sed "s/{{ INSTANCE_SMTP_SENDER_ADDRESS }}/${INSTANCE_SMTP_SENDER_ADDRESS}/g" \
      | sed "s/{{ INSTANCE_HTML5_CLIENT_CSS_URL }}/${INSTANCE_HTML5_CLIENT_CSS_URL}/g" \
      | sed "s/{{ INSTANCE_HTML5_CLIENT_LOGO_IMAGE_URL }}/${INSTANCE_HTML5_CLIENT_LOGO_IMAGE_URL}/g" \
      | sed "s/{{ SPINNER_NEELZ_EMAIL }}/${SPINNER_NEELZ_EMAIL}/g" \
      | sed "s/{{ SPINNER_NEELZ_EMAIL_PASSWORD }}/${neelz_email_password}/g" \
      | sed "s/{{ SPINNER_ISHARE_BASE_URL }}/${ishare_base_url}/g" \
      | sed "s/{{ INSTANCE_MCU_PREFIX }}/${mcu_prefix}/g" \
      | sed "s/{{ INSTANCE_MCU_MOD_PREFIX }}/${mcu_mod_prefix}/g" \
      | sed "s/{{ INSTANCE_BACKGROUND_IMAGE_URL_LANDING_PAGE }}/${INSTANCE_BACKGROUND_IMAGE_URL_LANDING_PAGE}/g" \
      | sed "s/{{ INSTANCE_LOGO_IMAGE_URL }}/${INSTANCE_LOGO_IMAGE_URL}/g" \
      | sed "s/{{ INSTANCE_LOGO_IMAGE_EMAIL_URL }}/${INSTANCE_LOGO_IMAGE_EMAIL_URL}/g" \
      | sed "s/{{ INSTANCE_DEFAULT_PRESENTATION_URL }}/${INSTANCE_DEFAULT_PRESENTATION_URL}/g" \
      > "${ENV_FILE_NAME}"

}

function assemble_variables_scss_file {

  echo " - assembling ${VARIABLES_SCSS_FILE_NAME}"

  cat "${TEMPLATE_VARIABLES_SCSS_FILE_NAME}" \
      | sed "s/{{ INSTANCE_BACKGROUND_IMAGE_URL_LANDING_PAGE }}/${INSTANCE_BACKGROUND_IMAGE_URL_LANDING_PAGE}/g" \
      | sed "s/{{ INSTANCE_LOGO_IMAGE_URL }}/${INSTANCE_LOGO_IMAGE_URL}/g" \
      | sed "s/{{ INSTANCE_LOGO_WITH_TEXT_IMAGE_URL }}/${INSTANCE_LOGO_WITH_TEXT_IMAGE_URL}/g" \
      > "${VARIABLES_SCSS_FILE_NAME}"

}

function assemble_nginx_conf_file {

  echo " - assembling ${NGINX_CONF_FILE_NAME}"

  cat "${TEMPLATE_NGINX_CONF_FILE_NAME}" \
      | sed "s/{{ INSTANCE_NAME }}/${INSTANCE_NAME}/g" \
      | sed "s/{{ INSTANCE_PORT }}/${INSTANCE_PORT}/g" \
      > "${NGINX_CONF_FILE_NAME}"

}

#...>>

#clone / pull from repository: <<

if [ ! -d "${INSTANCE_TARGET_DIR}" ]; then

  echo " - cloning branch ${KONKRET_BIGBLUE_BRANCH} from ${KONKRET_BIGBLUE_REPOSITORY_URL}"
  cd "${BIGBLUE_ROOT_DIR}"
  git clone --branch "${KONKRET_BIGBLUE_BRANCH}" "${KONKRET_BIGBLUE_REPOSITORY_URL}" "${INSTANCE_NAME}"

fi

echo " - doing a <git pull -a> from repository"
cd "${INSTANCE_TARGET_DIR}"
git pull -a

#...>>

#copy/renew assets from web locations: <<

INSTANCE_TARGET_PUBLIC_DIR="${INSTANCE_TARGET_DIR}public/"
if [ ! -d "${INSTANCE_TARGET_PUBLIC_DIR}" ]; then
  mkdir -p "${INSTANCE_TARGET_PUBLIC_DIR}"
  echo " ~ needed to create <public> folder (Is this your first run?)"
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
FAVICON_FILE_NAME=$(echo "${INSTANCE_FAVICON_URL_ORIG}" | sed "${REGEX_FILENAME_ONLY}");

echo " - emptying <public> folder (will be rebuilt)"
rm -f "./${HTML5_CLIENT_CSS_FILE_NAME}" \
      "./${HTML5_CLIENT_LOGO_FILE_NAME}" \
      "./${BACKGROUND_IMAGE_LANDING_PAGE_FILE_NAME}" \
      "./${LOGO_FILE_NAME}" \
      "./${LOGO_WITH_TEXT_FILE_NAME}" \
      "./${LOGO_EMAIL_FILE_NAME}" \
      "./${DEFAULT_PRESENTATION_FILE_NAME}" \
      "./${FAVICON_FILE_NAME}"

echo " - wget ${INSTANCE_HTML5_CLIENT_CSS_URL_ORIG}"
wget -q "${INSTANCE_HTML5_CLIENT_CSS_URL_ORIG}"
echo " - wget ${INSTANCE_HTML5_CLIENT_LOGO_IMAGE_URL_ORIG}"
wget -q "${INSTANCE_HTML5_CLIENT_LOGO_IMAGE_URL_ORIG}"
echo " - wget ${INSTANCE_BACKGROUND_IMAGE_URL_LANDING_PAGE_ORIG}"
wget -q "${INSTANCE_BACKGROUND_IMAGE_URL_LANDING_PAGE_ORIG}"
echo " - wget ${INSTANCE_LOGO_IMAGE_URL_ORIG}"
wget -q "${INSTANCE_LOGO_IMAGE_URL_ORIG}"
echo " - wget ${INSTANCE_LOGO_WITH_TEXT_IMAGE_URL_ORIG}"
wget -q "${INSTANCE_LOGO_WITH_TEXT_IMAGE_URL_ORIG}"
echo " - wget ${INSTANCE_LOGO_EMAIL_IMAGE_URL_ORIG}"
wget -q "${INSTANCE_LOGO_EMAIL_IMAGE_URL_ORIG}"
echo " - wget ${INSTANCE_DEFAULT_PRESENTATION_URL_ORIG}"
wget -q "${INSTANCE_DEFAULT_PRESENTATION_URL_ORIG}"
echo " - wget ${INSTANCE_FAVICON_URL_ORIG}"
wget -q "${INSTANCE_FAVICON_URL_ORIG}"

#...>>

#generate config files from templates and the values we determined above: <<

INSTANCE_URL_ESCAPED=$(echo "${INSTANCE_URL}" | sed $SEDEX_ESCAPE_SLASHES)

INSTANCE_HTML5_CLIENT_CSS_URL="${INSTANCE_URL_ESCAPED}${HTML5_CLIENT_CSS_FILE_NAME}"
INSTANCE_HTML5_CLIENT_LOGO_IMAGE_URL="${INSTANCE_URL_ESCAPED}${HTML5_CLIENT_LOGO_FILE_NAME}"
INSTANCE_BACKGROUND_IMAGE_URL_LANDING_PAGE="${INSTANCE_URL_ESCAPED}${BACKGROUND_IMAGE_LANDING_PAGE_FILE_NAME}"
INSTANCE_LOGO_IMAGE_URL="${INSTANCE_URL_ESCAPED}${LOGO_FILE_NAME}"
INSTANCE_LOGO_WITH_TEXT_IMAGE_URL="${INSTANCE_URL_ESCAPED}${LOGO_WITH_TEXT_FILE_NAME}"
INSTANCE_LOGO_EMAIL_IMAGE_URL="${INSTANCE_URL_ESCAPED}${LOGO_EMAIL_FILE_NAME}"
INSTANCE_DEFAULT_PRESENTATION_URL="${INSTANCE_URL_ESCAPED}${DEFAULT_PRESENTATION_FILE_NAME}"

INSTANCE_DB_PASSWORD=$(openssl rand -hex 16)

INSTANCE_MCU_PREFIX="${INSTANCE_MCU_PREFIX}"
INSTANCE_MCU_MOD_PREFIX=$(openssl rand -hex 8)
MCU_PREFIX_LEN=${#INSTANCE_MCU_PREFIX}
if [ "${MCU_PREFIX_LEN}" -lt 5 ]; then
  echo " ~ MCU_PREFIX not passed or it is too short."
  INSTANCE_MCU_PREFIX=$(openssl rand -hex 8)
  echo " ~ Magic Cap User (MCU) prefix is now: ${INSTANCE_MCU_PREFIX}"
fi

INSTANCE_CONTAINER_NAME="bigblue-${INSTANCE_NAME}"
INSTANCE_RELEASE_NAME="release-v2"

assemble_docker_compose_yml_file
assemble_env_file

#build container:

function rebuild_restart_containers {

  cd "${INSTANCE_TARGET_DIR}"
  docker-compose down
  ./scripts/image_build.sh "${INSTANCE_CONTAINER_NAME}" "${INSTANCE_RELEASE_NAME}"
  echo " - Bringing containers up ..."
  docker-compose up -d

  #wait a while for containers being ready:
  echo " ~ sleep for 20 seconds, please stand by, as this is intented"
  sleep 20
  echo " ~ okay. 20 seconds have passed by..."

}

echo " - First container built and launch"
rebuild_restart_containers

#handle secret key base
echo " - handling SECRET_KEY_BASE affairs ..."
INSTANCE_SECRET_KEY_BASE=$(docker run --rm "${INSTANCE_CONTAINER_NAME}:${INSTANCE_RELEASE_NAME}" bundle exec rake secret)

assemble_env_file
assemble_variables_scss_file

# rebuild container
echo " - stop, rebuild and restart containers..."
rebuild_restart_containers

# nginx configuration
echo " ~ NGINX configuration..."
assemble_nginx_conf_file

echo " - reloading nginx"
systemctl reload nginx

#...>>

# setup initial users: ...<<

cd "${INSTANCE_TARGET_DIR}"

# weirdly, database migrations seem to be made only upon a further container restart
sleep 5
docker-compose down
echo " ~ sleep for 10 seconds, please stand by, as this is intented"
sleep 10
echo " ~ okay. 10 seconds have passed by..."
docker-compose up -d
#wait a while for containers being ready:
echo " ~ sleep for 30 seconds, please stand by, as this is intented"
sleep 30
echo " ~ okay. 30 seconds have passed by..."

echo " ~ Initializing first user(s) for new instance"
# 1. admin
echo " - admin :: ${ADMIN_NAME} <${ADMIN_EMAIL}> and PW: ${ADMIN_PASSWORD}"
docker exec "${INSTANCE_CONTAINER_NAME}" bundle exec rake user:create["${ADMIN_NAME}","${ADMIN_EMAIL}","${ADMIN_PASSWORD}","admin"]

# 2. neelz user if appropriate
if [ "${WITH_NEELZ_LAYER_SUPPORT}" = "true" ]; then
  NEELZ_USER_NAME="°°${INSTANCE_NAME}°(neelZ)°°"
  NEELZ_USER_PASSWORD=$(openssl rand -hex 16)
  echo " - neelZ User :: ${NEELZ_USER_NAME} <${SPINNER_NEELZ_EMAIL}> and PW: ${NEELZ_USER_PASSWORD}"
  docker exec "${INSTANCE_CONTAINER_NAME}" bundle exec rake user:create["${NEELZ_USER_NAME}","${SPINNER_NEELZ_EMAIL}","${NEELZ_USER_PASSWORD}"]
fi
# ...>
echo " ~~~ I'm done for instance <${INSTANCE_NAME}>. Bye :)"
echo " ***"