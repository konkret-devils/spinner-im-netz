#!/bin/bash

SPINNER_ROOT_DIR="/opt/konkret-spinner/"
SPINNER_TEMPLATES_DIR="${SPINNER_ROOT_DIR}templates/"
SPINNER_CONF_FILE="${SPINNER_ROOT_DIR}.env"

echo "*** konkret spinner ***"
echo ""

# ###############################################
# load utilities (helper functions) :           #
# ###############################################
  source "${SPINNER_ROOT_DIR}core/functions.sh" #
# ###############################################

# ################################
# parse & eval config file .env: #
  echo " - reading .env file"    #
  source "${SPINNER_CONF_FILE}"  #
# ################################

# ################################################################################
# interrim ... should use getopt (not getopt*s*), also for additional variables, #
# or initializer config file should be source'd on top,                          #
# shadowing the default values in .env config file:                              #
# ################################################################################
  INSTANCE_NAME="${1}"                                                           #
  ADMIN_NAME="${2}"                                                              #
  ADMIN_EMAIL="${3}"                                                             #
  ADMIN_PASSWORD="${4}"                                                          #
  WITH_NEELZ_LAYER_SUPPORT="${5}"                                                #
  INSTANCE_MCU_PREFIX="${6}"                                                     #
# ################################################################################

INSTANCE_URL="https://${SPINNER_FQDN}/${INSTANCE_NAME}/"
INSTANCE_TARGET_DIR="${BIGBLUE_ROOT_DIR}${INSTANCE_NAME}/"
INSTANCE_CONTAINER_NAME="bigblue-${INSTANCE_NAME}"
INSTANCE_RELEASE_NAME="release-v2"

INSTANCE_DB_PASSWORD=$(openssl rand -hex 16)

if [ ${#INSTANCE_MCU_PREFIX} -lt 5 ]; then
  echo " ~ MCU_PREFIX not passed or it is too short."
  INSTANCE_MCU_PREFIX=$(openssl rand -hex 8)
  echo " ~ Magic Cap User (MCU) prefix is now: ${INSTANCE_MCU_PREFIX}"
fi

echo " ~ instance URL -> ${INSTANCE_URL}"
echo " ~ instance target directory -> ${INSTANCE_TARGET_DIR}"
echo " ~ instance container name -> ${INSTANCE_CONTAINER_NAME}"

CONFIG_FILES=( DOCKER_COMPOSE_YML \
               ENV \
               VARIABLES_SCSS \
               NGINX_CONF )

ASSETS=(       HTML5_CLIENT_CSS \
               HTML5_CLIENT_LOGO \
               BACKGROUND_IMAGE_LANDING_PAGE \
               LOGO \
               LOGO_WITH_TEXT \
               LOGO_EMAIL \
               DEFAULT_PRESENTATION \
               FAVICON )

TEMPLATE_DOCKER_COMPOSE_YML_FILE_NAME="${SPINNER_TEMPLATES_DIR}docker-compose.tmpl.yml"
TEMPLATE_ENV_FILE_NAME="${SPINNER_TEMPLATES_DIR}tmpl.env"
TEMPLATE_VARIABLES_SCSS_FILE_NAME="${SPINNER_TEMPLATES_DIR}assets/stylesheets/_variables.tmpl.scss"
TEMPLATE_NGINX_CONF_FILE_NAME="${SPINNER_TEMPLATES_DIR}tmpl.nginx.conf"

DOCKER_COMPOSE_YML_FILE_NAME="${INSTANCE_TARGET_DIR}docker-compose.yml"
ENV_FILE_NAME="${INSTANCE_TARGET_DIR}.env"
VARIABLES_SCSS_FILE_NAME="${INSTANCE_TARGET_DIR}app/assets/stylesheets/utilities/_variables.scss";
NGINX_CONF_FILE_NAME=""

VARIABLES_DOCKER_COMPOSE_YML=(  INSTANCE_CONTAINER_NAME \
                                INSTANCE_RELEASE_NAME \
                                INSTANCE_PORT \
                                POSTGRES_RELEASE \
                                INSTANCE_DB_PORT \
                                INSTANCE_DB_PASSWORD )

VARIABLES_ENV=(                 INSTANCE_NAME \
                                INSTANCE_NAME_PREFIX \
                                SPINNER_FQDN \
                                SPINNER_BBB_FQDN \
                                SPINNER_BBB_SECRET \
                                INSTANCE_DB_PASSWORD \
                                INSTANCE_SMTP_SERVER \
                                INSTANCE_SMTP_PORT \
                                INSTANCE_SMTP_DOMAIN \
                                INSTANCE_SMTP_USERNAME \
                                INSTANCE_SMTP_PASSWORD \
                                INSTANCE_SMTP_STARTTLS_AUTO \
                                INSTANCE_SMTP_SENDER_NAME \
                                INSTANCE_SMTP_SENDER_ADDRESS \
                                INSTANCE_HTML5_CLIENT_CSS_URL \
                                INSTANCE_HTML5_CLIENT_LOGO_IMAGE_URL \
                                SPINNER_NEELZ_EMAIL \
                                SPINNER_NEELZ_EMAIL_PASSWORD \
                                SPINNER_ISHARE_BASE_URL \
                                INSTANCE_MCU_PREFIX \
                                INSTANCE_MCU_MOD_PREFIX \
                                INSTANCE_BACKGROUND_IMAGE_LANDING_PAGE_URL \
                                INSTANCE_LOGO_IMAGE_URL \
                                INSTANCE_LOGO_IMAGE_EMAIL_URL \
                                INSTANCE_DEFAULT_PRESENTATION_URL )

VARIABLES_VARIABLES_SCSS=(      INSTANCE_BACKGROUND_IMAGE_LANDING_PAGE_URL \
                                INSTANCE_LOGO_IMAGE_URL \
                                INSTANCE_LOGO_WITH_TEXT_IMAGE_URL )

VARIABLES_NGINX_CONF=(          INSTANCE_NAME \
                                INSTANCE_PORT )

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

    MAX_USED_GL_PORT=$(ls -l "${NGINX_CONF_DIR}"*.nginx.conf | tail -n 1 | awk '{print $NF}' | sed 's/.*\([0-9][0-9][0-9][0-9][0-9]*\)_[0-9][0-9][0-9][0-9][0-9]*.*$/\1/g')
    NEXT_GL_PORT=$(expr "${MAX_USED_GL_PORT}" + 1)
    while [ $(netstat -ntlpu | cut -f4 | grep ":${NEXT_GL_PORT}" | wc -l) -gt 0 ]; do
      NEXT_GL_PORT=$(expr "${NEXT_GL_PORT}" + 1)
    done

    MAX_USED_DB_PORT=$(ls -l "${NGINX_CONF_DIR}"*.nginx.conf | tail -n 1 | awk '{print $NF}' | sed 's/.*[0-9][0-9][0-9][0-9][0-9]*_\([0-9][0-9][0-9][0-9][0-9]*\).*$/\1/g')
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

NGINX_CONF_FILE_NAME="${NGINX_CONF_DIR}${INSTANCE_PORT}_${INSTANCE_DB_PORT}_${INSTANCE_NAME}.nginx.conf"

echo " ~ :: mainContainer:PORT=${INSTANCE_PORT} / postgresDBContainer:PORT=${INSTANCE_DB_PORT}"

# ...>>

# template processing: <<

copy_templates_to_config_files "${CONFIG_FILES[@]}"

renew_assets "${INSTANCE_TARGET_DIR}" "${ASSETS[@]}"

template_fill_in_local_asset_urls "${ENV_FILE_NAME}" "${INSTANCE_URL}" "${ASSETS[@]}"

template_fill_in_local_asset_urls "${VARIABLES_SCSS_FILE_NAME}" "${INSTANCE_URL}" "${ASSETS[@]}"

reflective_replace_variables "${CONFIG_FILES[@]}"

#clone / pull from repository: <<

if [ ! -d "${INSTANCE_TARGET_DIR}" ]; then
  echo " - cloning branch ${GREENLIGHT_LIKE_BRANCH} from ${GREENLIGHT_LIKE_REPOSITORY_URL}"
  cd "${BIGBLUE_ROOT_DIR}"
  git clone --branch "${GREENLIGHT_LIKE_BRANCH}" "$GREENLIGHT_LIKE_REPOSITORY_URL}" "${INSTANCE_NAME}"
else
  echo " - doing a <git pull -a> from repository"
  cd "${INSTANCE_TARGET_DIR}"
  git pull -a
fi

#build container:

echo " - First container built and launch"
rebuild_restart_containers "${INSTANCE_CONTAINER_NAME}" "${INSTANCE_RELEASE_NAME}" "${INSTANCE_TARGET_DIR}"
sleep_n_seconds 20

#handle secret key base
echo " - handling SECRET_KEY_BASE affairs ..."
INSTANCE_SECRET_KEY_BASE=$(docker run --rm "${INSTANCE_CONTAINER_NAME}:${INSTANCE_RELEASE_NAME}" bundle exec rake secret)

template_replace_variable "${ENV_FILE_NAME}" INSTANCE_SECRET_KEY_BASE "${INSTANCE_SECRET_KEY_BASE}"

# rebuild container
echo " - stop, rebuild and restart containers..."
rebuild_restart_containers "${INSTANCE_CONTAINER_NAME}" "${INSTANCE_RELEASE_NAME}" "${INSTANCE_TARGET_DIR}"

sleep_n_seconds 20

echo " - reloading nginx"
systemctl reload nginx

#...>>

# setup initial users: ...<<

cd "${INSTANCE_TARGET_DIR}"

# weirdly, database migrations seem to be made only upon a further container restart

sleep_n_seconds 5
restart_containers" ${INSTANCE_CONTAINER_NAME}"

docker-compose up -d
sleep_n_seconds 30

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