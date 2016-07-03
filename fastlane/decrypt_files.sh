#!/bin/sh

ABSOLUTE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

openssl aes-256-cbc -k $ENCRYPTION_PASSWORD -in $ABSOLUTE_PATH/Certificates/distribution.p12.enc -d -a -out $ABSOLUTE_PATH/Certificates/distribution.p12
openssl aes-256-cbc -k $ENCRYPTION_PASSWORD -in $ABSOLUTE_PATH/Certificates/distribution.cer.enc -d -a -out $ABSOLUTE_PATH/Certificates/distribution.cer
openssl aes-256-cbc -k $ENCRYPTION_PASSWORD -in $ABSOLUTE_PATH/Certificates/Development_com.andrewferrier.imbk.mobileprovision.enc -d -a -out $ABSOLUTE_PATH/Certificates/Development_com.andrewferrier.imbk.mobileprovision
