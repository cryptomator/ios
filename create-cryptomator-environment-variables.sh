#!/bin/sh
cat > ./CryptomatorEnvironmentVariables.h << EOM

#define DROPBOX_APP_URL_SCHEME db-${DROPBOX_APP_KEY}
EOM

