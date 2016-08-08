#!/bin/sh

ABSOLUTE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. $ABSOLUTE_PATH/local_fastlane_testing.sh

travis encrypt KEY_PASSWORD=$KEY_PASSWORD --add
travis encrypt ENCRYPTION_PASSWORD=$ENCRYPTION_PASSWORD --add
travis encrypt HOCKEY_API_TOKEN=$HOCKEY_API_TOKEN --add
travis encrypt HOCKEY_APP_ID=$HOCKEY_APP_ID --add
