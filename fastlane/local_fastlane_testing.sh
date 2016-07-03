#!/bin/sh

export KEY_PASSWORD=XXX
export ENCRYPTION_PASSWORD=XXX
export HOCKEY_API_TOKEN=XXX
export HOCKEY_APP_ID=XXX

openssl aes-256-cbc -k $ENCRYPTION_PASSWORD -in fastlane/Certificates/distribution.p12.enc -d -a -out fastlane/Certificates/distribution.p12
openssl aes-256-cbc -k $ENCRYPTION_PASSWORD -in fastlane/Certificates/Development_com.andrewferrier.imbk.mobileprovision.enc -d -a -out fastlane/Certificates/Development_com.andrewferrier.imbk.mobileprovision
