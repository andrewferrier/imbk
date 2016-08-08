#!/bin/sh

ABSOLUTE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export KEY_PASSWORD=XXX
export ENCRYPTION_PASSWORD=XXX
export HOCKEY_API_TOKEN=XXX
export HOCKEY_APP_ID=XXX
export BMS_ACCESS_KEY=XXX

$ABSOLUTE_PATH/decrypt_files.sh
