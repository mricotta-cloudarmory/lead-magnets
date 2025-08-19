#!/usr/bin/env bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./zip-kits.ps1

aws s3 sync kits/ s3://cloud-armory-lead-magnets --delete --profile landingpage

aws cloudfront create-invalidation --profile landingpage --distribution-id "E2RDLQ3KBH5OTV" --paths "/*"