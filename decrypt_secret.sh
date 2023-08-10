#!/bin/sh

# Decrypt the file
mkdir ./secrets
# --batch to prevent interactive command
# --yes to assume "yes" for questions
gpg --quiet --batch --yes --decrypt --passphrase="testinggithubactions123" \
--output ./secrets/my_secret my_secret.gpg