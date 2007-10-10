#!/bin/sh

export BUILD_DIR=${BUILD_DIR:?"error: Environment variable BUILD_DIR must exist, aborting."}
export BUILD_SQL_DIR=${BUILD_SQL_DIR:?"error: Environment variable BUILD_SQL_DIR must exist, aborting."}
export BZIP2_CMD=${BZIP2_CMD:?"error: Environment variable BZIP2_CMD must exist, aborting."}
export CONFIGURATION=${CONFIGURATION:?"error: Environment variable CONFIGURATION must exist, aborting."}
export DISTRIBUTION_BASE_FILE_NAME=${DISTRIBUTION_BASE_FILE_NAME:?"error: Environment variable DISTRIBUTION_BASE_FILE_NAME must exist, aborting."}
export DISTRIBUTION_BASE_SOURCE_FILE_NAME=${DISTRIBUTION_BASE_SOURCE_FILE_NAME:?"error: Environment variable DISTRIBUTION_BASE_SOURCE_FILE_NAME must exist, aborting."}
export DISTRIBUTION_TARGET_DIR=${DISTRIBUTION_TARGET_DIR:?"error: Environment variable DISTRIBUTION_TARGET_DIR must exist, aborting."}
export DISTRIBUTION_ROOT=${DISTRIBUTION_ROOT:?"error: Environment variable DISTRIBUTION_ROOT must exist, aborting."}
export DISTRIBUTION_DMG_CONVERT_OPTS=${DISTRIBUTION_DMG_CONVERT_OPTS:?"error: Environment variable DISTRIBUTION_DMG_CONVERT_OPTS must exist, aborting."}
export DISTRIBUTION_DMG_VOL_NAME=${DISTRIBUTION_DMG_VOL_NAME:?"error: Environment variable DISTRIBUTION_DMG_VOL_NAME must exist, aborting."}
export DISTRIBUTION_ROOT_NAME=${DISTRIBUTION_ROOT_NAME:?"error: Environment variable DISTRIBUTION_ROOT_NAME must exist, aborting."}
export DOCUMENTATION_TARGET_DIR=${DOCUMENTATION_TARGET_DIR:?"error: Environment variable DOCUMENTATION_TARGET_DIR must exist, aborting."}
export DOCUMENTATION_README_DIR=${DOCUMENTATION_README_DIR:?"error: Environment variable DOCUMENTATION_README_DIR must exist, aborting."}
export FIND=${FIND:?"error: Environment variable FIND must exist, aborting."}
export GZIP_CMD=${GZIP_CMD:?"error: Environment variable GZIP_CMD must exist, aborting."}
export PERL=${PERL:?"Environment variable PERL must exist, aborting."}
export PROJECT_DIR=${PROJECT_DIR:?"Environment variable PROJECT_DIR must exist, aborting."}
export PROJECT_NAME=${PROJECT_NAME:?"Environment variable PROJECT_NAME must exist, aborting."}
export RSYNC=${RSYNC:?"Environment variable RSYNC must exist, aborting."}
export SQLITE=${SQLITE:?"Environment variable SQLITE must exist, aborting."}
export TEMP_FILES_DIR=${TEMP_FILES_DIR:?"error: Environment variable TEMP_FILES_DIR must exist, aborting."}


if [ "${CONFIGURATION}" != "Release" ]; then echo "$0:$LINENO: error: Distribution can only be built under the 'Release' configuration."; exit 1; fi;

${PERL} -e 'require DBD::SQLite;' >/dev/null 2>&1
if [ $? != 0 ]; then echo "$0:$LINENO: error: The perl module 'DBD::SQLite' must be installed in order to build the the target '${TARGETNAME}'."; exit 1; fi;  

if [ "${P7ZIP}" == "" ]; then
  if [ -x 7za ]; then P7ZIP="7za";
  elif [ -x /usr/local/bin/7za ]; then P7ZIP="/usr/local/bin/7za";
  elif [ -x /opt/local/bin/7za ]; then P7ZIP="/opt/local/bin/7za";
  elif [ -x /sw/bin/7za ]; then P7ZIP="/sw/bin/7za";
  fi
fi

compress_tarball()
{
  local TARBALL_DIR="$1";
  local TARBALL_FILE="$2";
  local TARBALL_FILEPATH="${TARBALL_DIR}/${TARBALL_FILE}";

  if [ ! -f "${TARBALL_FILEPATH}" ] || [ -z "${TARBALL_FILEPATH}" ]; then return 1; fi;

  echo "debug: Compressing tarball '${TARBALL_FILE}' with bzip2."
  "${BZIP2_CMD}" -k9 "${TARBALL_FILEPATH}"
  if [ $? != 0 ]; then echo "$0:$LINENO: error: Error creating '${TARBALL_FILE}.bz2' with bzip2 command '${BZIP2_CMD}'."; return 1; fi;

  echo "debug: Compressing tarball '${TARBALL_FILE}' with gzip."
  "${GZIP_CMD}" -c9 "${TARBALL_FILEPATH}" > "${TARBALL_FILEPATH}.gz"
  if [ $? != 0 ]; then echo "$0:$LINENO: error: Error creating '${TARBALL_FILE}.gz' with gzip command '${GZIP_CMD}'."; return 1; fi;

  if [ -x "${P7ZIP}" ]; then
    echo "debug: Compressing tarball '${TARBALL_FILE}' with p7zip."
    "${P7ZIP}" a "${TARBALL_FILEPATH}.7z" -mx=9 "${TARBALL_FILEPATH}"
    if [ $? != 0 ]; then echo "$0:$LINENO: error: Error creating '${TARBALL_FILE}.7z' with p7zip command '${P7ZIP}'."; return 1; fi;
    chmod ugo+r "${TARBALL_FILEPATH}.7z"
  fi
}

create_tarball()
{
  local TARBALL_DIR="$1";
  local TARBALL_FILE="$2";
  local TARBALL_ARCHIVE_ROOT="$3";
  local TARBALL_ARCHIVE="$4";

  local CURRENT_DIR=`pwd`;
  
  cd "${TARBALL_ARCHIVE_ROOT}" && \
    echo "cwd: " `pwd` && \
    tar cf "${TARBALL_DIR}/${TARBALL_FILE}" "${TARBALL_ARCHIVE}" && \
    compress_tarball "${TARBALL_DIR}" "${TARBALL_FILE}" && \
    rm "${TARBALL_DIR}/${TARBALL_FILE}"

  local RETURN_RESULT="$?";
  
  cd "${CURRENT_DIR}"
  
  return $RETURN_RESULT;
}

create_dmg()
{
  local DMG_DIR="$1";
  local DMG_FILE="$2";
  local DMG_VOL_NAME="$3";
  local DMG_ARCHIVE="$4";
  local DMG_CONVERT_OPS="$5";
  local DMG_INTERNET_ENABLE="$6";
  
  local DMG_FILEPATH="${DMG_DIR}/${DMG_FILE}";

  local DMG_TMP_FILE="tmp_${DMG_FILE}";
  local DMG_TMP_FILEPATH="${DMG_DIR}/${DMG_TMP_FILE}";
  
  echo "debug: Creating '${DMG_FILE}' .dmg image."
  hdiutil makehybrid -o "${DMG_TMP_FILEPATH}" -hfs -hfs-volume-name "${DMG_VOL_NAME}" "${DMG_DIR}/${DMG_ARCHIVE}"
  if [ $? != 0 ]; then echo "$0:$LINENO: error: Error creating temporary '${DMG_FILE}' with the 'hdiutil' command."; return 1; fi;
  echo "debug: Compressing .dmg image."
  hdiutil convert ${DMG_CONVERT_OPS} -o "${DMG_FILEPATH}" "${DMG_TMP_FILEPATH}"
  if [ $? != 0 ]; then echo "$0:$LINENO: error: Error compressing '${DMG_FILE}' with the 'hdiutil' command."; return 1; fi;
  rm -f "${DMG_TMP_FILEPATH}"
  if [ ! -f "${DMG_FILEPATH}" ]; then echo "$0:$LINENO: error: Did not create the .dmg image '${DMG_FILE}'."; return 1; fi;
  if [ "${DMG_INTERNET_ENABLE}" == "YES" ]; then
    hdiutil internet-enable -yes "${DMG_FILEPATH}"
    if [ $? != 0 ]; then echo "$0:$LINENO: error: Unable to Internet Enable '${DMG_FILE}' with the 'hdiutil' command."; return 1; fi;
  fi;
}

if [ ! -r "${DISTRIBUTION_SQL_FILES_FILE}" ]; then echo "$0:$LINENO: error: The sql database creation file 'files.sql' does not exist in '${BUILD_SQL_DIR}'."; exit 1; fi;

# Init and load the database
if [ ! -d "${DISTRIBUTION_SQL_DATABASE_DIR}" ]; then mkdir -p "${DISTRIBUTION_SQL_DATABASE_DIR}"; fi;
if [ "${DISTRIBUTION_SQL_FILES_FILE}" -nt "${DISTRIBUTION_SQL_DATABASE_FILE}" ]; then
  rm -rf "${DISTRIBUTION_SQL_DATABASE_FILE}"
  sync
  "${SQLITE}" "${DISTRIBUTION_SQL_DATABASE_FILE}" <"${DISTRIBUTION_SQL_FILES_FILE}"
  if [ $? != 0 ]; then echo "$0:$LINENO: error: Distribution SQL database 'files' data load failed."; exit 1; fi;
fi

if [ ! -x "${FILE_CHECK_SCRIPT}" ] ; then echo "$0:$LINENO: error: The file check script '${FILE_CHECK_SCRIPT}' does not exist."; exit 1; fi;

rm -rf "${DISTRIBUTION_TARGET_DIR}"

# Create the binary distribution

echo "debug: Creating Mac OS X framework binary distribution '${DISTRIBUTION_ROOT_NAME}'."

export DISTRIBUTION_TEMP_BINARY_ROOT="${DISTRIBUTION_TEMP_BINARY_DIR}/${DISTRIBUTION_ROOT_NAME}";

rm -rf "${DISTRIBUTION_TEMP_BINARY_DIR}"
mkdir -p "${DISTRIBUTION_TEMP_BINARY_ROOT}"

echo "debug: Copying release products to '${DISTRIBUTION_ROOT_NAME}'."

"${RSYNC}" -a --cvs-exclude "${BUILD_DIR}/${CONFIGURATION}/RegexKit.framework" "${DISTRIBUTION_TEMP_BINARY_ROOT}" && \
  "${RSYNC}" -a --cvs-exclude "${BUILD_DIR}/${CONFIGURATION}/Documentation" "${DISTRIBUTION_TEMP_BINARY_ROOT}" && \
  "${RSYNC}" -a --cvs-exclude ChangeLog LICENSE README ReleaseNotes "${BUILD_DISTRIBUTION_DIR}/Documentation.html" "${DISTRIBUTION_TEMP_BINARY_ROOT}"
if [ $? != 0 ]; then echo "$0:$LINENO: error: Unable to copy release products."; exit 1; fi;

if [ ${STRIP_INSTALLED_PRODUCT} == "YES" ]; then
  echo "Stripping release products of debugging information."
  strip -S "${DISTRIBUTION_TEMP_BINARY_ROOT}/RegexKit.framework/Versions/A/RegexKit"
  if [ $? != 0 ]; then echo "$0:$LINENO: error: Unable to strip release products."; exit 1; fi;
fi

# If SetFile is available, this adds some polish to the text files for Macintosh users.
# Specifically- Sets the type of file to TEXT so that double-clicking on the file works correctly

if [ -x "${SYSTEM_DEVELOPER_TOOLS}/SetFile" ]; then
  "${SYSTEM_DEVELOPER_TOOLS}/SetFile" -t 'TEXT' "${DISTRIBUTION_TEMP_BINARY_ROOT}/ChangeLog"
  "${SYSTEM_DEVELOPER_TOOLS}/SetFile" -t 'TEXT' "${DISTRIBUTION_TEMP_BINARY_ROOT}/LICENSE"
  "${SYSTEM_DEVELOPER_TOOLS}/SetFile" -t 'TEXT' "${DISTRIBUTION_TEMP_BINARY_ROOT}/README"
  "${SYSTEM_DEVELOPER_TOOLS}/SetFile" -t 'TEXT' "${DISTRIBUTION_TEMP_BINARY_ROOT}/ReleaseNotes"
fi;

# Check against the files database to make sure everything is the way we expect it to be.

"${FILE_CHECK_SCRIPT}" "${DISTRIBUTION_SQL_DATABASE_FILE}" 'Binary' "${DISTRIBUTION_TEMP_BINARY_ROOT}"
if [ $? != 0 ]; then echo "$0:$LINENO: error: Binary distribution check failed."; exit 1; fi;

create_tarball "${DISTRIBUTION_TEMP_BINARY_DIR}" "${DISTRIBUTION_BASE_FILE_NAME}.tar" "${DISTRIBUTION_TEMP_BINARY_DIR}" "${DISTRIBUTION_ROOT_NAME}"
if [ $? != 0 ]; then exit 1; fi;
create_dmg "${DISTRIBUTION_TEMP_BINARY_DIR}" "${DISTRIBUTION_BASE_FILE_NAME}.dmg" "${DISTRIBUTION_DMG_VOL_NAME}" "${DISTRIBUTION_ROOT_NAME}" "${DISTRIBUTION_DMG_CONVERT_OPTS}" "YES"
if [ $? != 0 ]; then exit 1; fi;

echo "debug: Copying Mac OS X framework binary distribution bundles to '${DISTRIBUTION_TARGET_DIR}'."

mkdir -p "${DISTRIBUTION_TARGET_DIR}" && \
  cd "${DISTRIBUTION_TEMP_BINARY_DIR}" && \
  "${RSYNC}" -a "${DISTRIBUTION_BASE_FILE_NAME}.dmg" *.tar.* "${DISTRIBUTION_TARGET_DIR}"
if [ $? != 0 ]; then echo "$0:$LINENO: error: Unable to copy release bundles."; exit 1; fi;
cd "${PROJECT_DIR}"


# Create the source distribution

echo "debug: Creating the source distribution '${DISTRIBUTION_ROOT_SOURCE_NAME}'."

export DISTRIBUTION_TEMP_SOURCE_ROOT="${DISTRIBUTION_TEMP_SOURCE_DIR}/${DISTRIBUTION_ROOT_SOURCE_NAME}";

rm -rf "${DISTRIBUTION_TEMP_SOURCE_DIR}"
mkdir -p "${DISTRIBUTION_TEMP_SOURCE_ROOT}"

echo "debug: Copying project source to '${DISTRIBUTION_TEMP_SOURCE_ROOT}'."
"${RSYNC}" -a --cvs-exclude \
    --exclude="\.*" \
    --exclude="*~" \
    --exclude="#*#" \
    --exclude="Source/Headers/RegexKit/pcre.h" \
    --exclude="Source/pcre" \
    ChangeLog LICENSE README README.MacOSX ReleaseNotes GNUstep Source "${BUILD_DIR}/${CONFIGURATION}/Documentation" \
    "${DISTRIBUTION_TEMP_SOURCE_ROOT}" && \
  "${RSYNC}" -a --cvs-exclude "${BUILD_DISTRIBUTION_DIR}/distribution_pcre.h" "${DISTRIBUTION_TEMP_SOURCE_ROOT}/Source/Headers/RegexKit/pcre.h" && \
  mkdir -p "${DISTRIBUTION_TEMP_SOURCE_ROOT}/${PROJECT_NAME}.xcodeproj/" && \
  "${RSYNC}" -a "${PROJECT_NAME}.xcodeproj/project.pbxproj" "${DISTRIBUTION_TEMP_SOURCE_ROOT}/${PROJECT_NAME}.xcodeproj/project.pbxproj"

if [ $? != 0 ]; then echo "$0:$LINENO: error: Unable to copy project source to temporary build area."; exit 1; fi;

# If SetFile is available, this adds some polish to the text files for Macintosh users.
# Specifically- Sets the type of file to TEXT so that double-clicking on the file works correctly

if [ -x "${SYSTEM_DEVELOPER_TOOLS}/SetFile" ]; then
  "${SYSTEM_DEVELOPER_TOOLS}/SetFile" -t 'TEXT' "${DISTRIBUTION_TEMP_SOURCE_ROOT}/ChangeLog"
  "${SYSTEM_DEVELOPER_TOOLS}/SetFile" -t 'TEXT' "${DISTRIBUTION_TEMP_SOURCE_ROOT}/LICENSE"
  "${SYSTEM_DEVELOPER_TOOLS}/SetFile" -t 'TEXT' "${DISTRIBUTION_TEMP_SOURCE_ROOT}/README"
  "${SYSTEM_DEVELOPER_TOOLS}/SetFile" -t 'TEXT' "${DISTRIBUTION_TEMP_SOURCE_ROOT}/README.MacOSX"
  "${SYSTEM_DEVELOPER_TOOLS}/SetFile" -t 'TEXT' "${DISTRIBUTION_TEMP_SOURCE_ROOT}/ReleaseNotes"
fi;

# Check against the files database to make sure everything is the way we expect it to be.

"${FILE_CHECK_SCRIPT}" "${DISTRIBUTION_SQL_DATABASE_FILE}" 'Source' "${DISTRIBUTION_TEMP_SOURCE_ROOT}"
if [ $? != 0 ]; then echo "$0:$LINENO: error: Source distribution check failed."; exit 1; fi;


create_tarball "${DISTRIBUTION_TEMP_SOURCE_DIR}" "${DISTRIBUTION_BASE_SOURCE_FILE_NAME}.tar" "${DISTRIBUTION_TEMP_SOURCE_DIR}" "${DISTRIBUTION_ROOT_SOURCE_NAME}"
if [ $? != 0 ]; then exit 1; fi;

mkdir -p "${DISTRIBUTION_TARGET_DIR}" && \
  cd "${DISTRIBUTION_TEMP_SOURCE_DIR}" && \
  "${RSYNC}" -a *.tar.* "${DISTRIBUTION_TARGET_DIR}"
if [ $? != 0 ]; then echo "$0:$LINENO: error: Unable to copy source tarballs to distribution directory."; exit 1; fi;
cd "${PROJECT_DIR}"


exit 0;
