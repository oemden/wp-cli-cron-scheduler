#!/bin/bash

# list all Wp cron jobs and use wp cron event run <some-cron-job> to bypass Cloudflare's Anti-bot WAF rules.
# standard wp cron test fails:
#	   Error: WP-Cron spawn failed with error: cURL error 7: Failed to connect to exemple.com port 443: Connection refused
# 'wp cron event run' can not run "all Jobs" like the 'wp cron test' command does so we list cron jobs and run them in a loop.
# v0.1
#
#
# n8n fails to find wp, so let's help it:
source $HOME/.bash_profile

# Move to Wordpress Home Directory
cd  $HOME/www

# make a list and run jobs one by one
wp cron event list --format=json | grep -o '"hook":"[^"]*"' | cut -d'"' -f4 | while read hook; do
  wp cron event run "$hook"
done

