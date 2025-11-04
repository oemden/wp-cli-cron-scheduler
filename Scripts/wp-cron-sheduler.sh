#!/bin/bash

# list all Wp cron jobs and use wp cron event run <some-cron-job> to bypass Cloudflare's Anti-bot WAF rules.
# standard wp cron test fails:
#          Error: WP-Cron spawn failed with error: cURL error 7: Failed to connect to exemple.com port 443: Connection refused
# 'wp cron event run' can not run "all Jobs" like the 'wp cron test' command does so we list cron jobs and run them in a loop.
# 
# v0.2
#
#
# n8n fails to find wp, so let's help it:
source $HOME/.bash_profile

# Move to Wordpress Home Directory
# TODO: add this as an .env variable
cd  $HOME/www

#############################################################################

# Get current time in seconds since epoch
CURRENT_EPOCH=$(date +%s)

# Fetch cron events as JSON
echo "fetch cron Jobs"
wp cron event list --format=json | grep -o '"hook":"[^"]*","next_run_gmt":"[^"]*"' | while read line; do
  # Extract hook name
  HOOK=$(echo "$line" | grep -o '"hook":"[^"]*"' | cut -d'"' -f4)

  # Extract next_run_gmt
  NEXT_RUN=$(echo "$line" | grep -o '"next_run_gmt":"[^"]*"' | cut -d'"' -f4)

  # Convert next_run_gmt to epoch seconds
  NEXT_EPOCH=$(date -d "${NEXT_RUN}" +%s 2>/dev/null)

  # Run if next_run_gmt is in the past or now
  if [ "${NEXT_EPOCH}" -le "${CURRENT_EPOCH}" ]; then
    echo "Running: $HOOK (due: ${NEXT_RUN})"
    wp cron event run "${HOOK}"
  else
    echo "No job to run for: ${HOOK}"
    echo "   -> Next job due date: ${NEXT_RUN}" && echo ""
  fi
done

