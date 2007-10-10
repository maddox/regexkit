#!/bin/sh

MAKE=${MAKE:?"Environment variable MAKE must exist, aborting."};
MAKEFILE_PCRE=${MAKEFILE_PCRE:?"Environment variable MAKEFILE_PCRE must exist, aborting."};

if [ ! -f "${MAKEFILE_PCRE}" ]; then echo "$0: $LINENO: error: The Makefile to build PCRE, '${MAKEFILE_PCRE}', does not exist, aborting." exit 1; fi;

# Determine if there has been a change that requires the pcre library to be cleaned.
if [ -f "${PCRE_BUILT_WITH_MAKEFILE}" ];   then DIFFERENT_MAKEFILE=`diff -q "${MAKEFILE_PCRE}" "${PCRE_BUILT_WITH_MAKEFILE}"`; fi;
if [ -f "${PCRE_BUILT_WITH_SCRIPT}" ];     then DIFFERENT_SCRIPT=`diff -q "$0" "${PCRE_BUILT_WITH_SCRIPT}"`; fi;
eval "${PCRE_BUILT_WITH_ENV_CMD}" > "${PCRE_BUILT_WITH_ENV_FILE}_now"
if [ -f "${PCRE_BUILT_WITH_ENV_FILE}" ];   then DIFFERENT_ENV=`diff -q "${PCRE_BUILT_WITH_ENV_FILE}" "${PCRE_BUILT_WITH_ENV_FILE}_now"`; fi;

if   [ "${DIFFERENT_ENV}"      !=  "" ];   then echo "debug: The build environment variables have changed since building the pcre library.";        NEEDS_CLEANING="Yes";
elif [ "${DIFFERENT_SCRIPT}"   !=  "" ];   then echo "debug: The build script '${PCRE_BUILD_SCRIPT}' has changed since building the pcre library."; NEEDS_CLEANING="Yes";
elif [ "${DIFFERENT_MAKEFILE}" !=  "" ];   then echo "debug: The makefile '${MAKEFILE_PCRE}' has changed since building the pcre library.";         NEEDS_CLEANING="Yes";
fi;

# Invoke Makefile.pcre with the 'clean' if needed.
if [ -r "PCRE_MAKE_OVERRIDE" ] && [ "$NEEDS_CLEANING" == "Yes" ]; then
  echo "$0:$LINENO: warning: The file 'PCRE_MAKE_OVERRIDE' exists but PCRE cleaning required, skipping clean.";
else
  if [ "$NEEDS_CLEANING" == "Yes" ];         then ${MAKE} -f "${MAKEFILE_PCRE}" clean; fi;
fi

# Create the directory we use for all our temporary files.
if [ ! -d "${PCRE_TEMP_ROOT}" ];           then mkdir -p "${PCRE_TEMP_ROOT}"; fi;

# Copy the environment variables, script (this script), and Makefile used to build the pcre library.
if [ ! -f "${PCRE_BUILT_WITH_ENV_FILE}" ]; then eval "${PCRE_BUILT_WITH_ENV_CMD}" > "${PCRE_BUILT_WITH_ENV_FILE}"; fi;
if [ ! -f "${PCRE_BUILT_WITH_SCRIPT}" ];   then cp "$0" "${PCRE_BUILT_WITH_SCRIPT}"; fi;
if [ ! -f "${PCRE_BUILT_WITH_MAKEFILE}" ]; then cp "${MAKEFILE_PCRE}" "${PCRE_BUILT_WITH_MAKEFILE}"; fi;

# Finally, invoke Makefile.pcre with ${ACTION} (which is nearly always 'build').
exec ${MAKE} -f "${MAKEFILE_PCRE}" ${ACTION};


