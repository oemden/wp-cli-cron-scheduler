# wp-cli cron scheduler

## Wordpress Automatic Cron Trigger via `wp-cli`

**Context**

If you protect your website with **Cloudflare's Anti-bot WAF rules**, `wp-cron.php` jobs will be blocked, and standard wp cron jobs will just fail, unless you can do an IP Access rule, which is not possible on Free tier ( as far as I know ).

**Solution**

The Trick is to call `wp-cron` from `ssh`.

It works, but:

Calling `php /path-to-wp-directory/www/wp-cron.php` from the cli will also fail: 
```
Error: WP-Cron spawn failed with error: cURL error 7: Failed to connect to your_wp_exemple.com port 443: Connection refused
```

So we'll then use `wp-cli` ( refer to this post on how to install it on OVH Mutualisé: ). 

`wp cron list` will work just fine, and calling a job too: `wp cron event run wp_site_health_scheduled_check` but, oh irony, `wp cron test` will fail.

Also `wp cron event run` can not run "all Jobs" like the `wp cron test` command does so we list cron jobs and run them in a loop.

n8n will uns SSH command on a schedule (e.g., hourly) and trigger cron jobs.

### There are 2 Scripts: ###

That list all wp cron jobs and use `wp cron event run <some-cron-job>` in a loop to run them and so bypass Cloudflare's Anti-bot WAF rules.


- `wp-run-all-jobs.sh`: 

Will run All jobs no matter their schedule and last run. A bit aggressive.

- `wp-cron-scheduler.sh`:

More subtile, this one will list all pending wp cron jobs and only run jobs where `next_run_gmt` <= current server time and skip future jobs entirely, run any jobs that are past due (catch up any missed depending on the schedule you've set in n8n)?

### n8n Automation

Automation is the whole idea. Automate the wp-cron jobs and bypass Cloudflare's anti-bot protection.

***Note:***
 Any Automation tool should work ( Make, Zapier ), I'll detail n8n here.

You can set N8n schedule to anything you want, once a day, every hours, combo.
this will reduces SSH calls (1/hour vs 5/min), jobs run at their actual due time (or soon after). No wasted execution of jobs not yet due ( each n8n workflow run is "faster").

Benefits:

- Clean separation: n8n scheduler handles frequency, WP cron handles eligibility
- So now we can Protect WP with Cloudflare's Anti-bot rules and yet have a working wp cron.


*Note:* you can also use this without beeing behind Cloudflare anti-bot rules.

## Setup

### web Hosting

**wp-cli**

- You need to have wp-cli set up and running on your host. [URL]()
- you need to set up an ssh Key ( do not use passwords for ssh connections ) and add it to your host's Authorized_keys. Or use a ssh user:password if you insist. 
n8n accept ssh keys with password by the way.

- copy one or both scripts. If you want a ready to go option, place them in your web hosting Home directory under `/$HOME/Scripts`  anywhere you want and adapt the scripts and n8n workflow accordingly.

### n8n

- Install this workflow: [URL]()
- Create you ssh Credential
- Set the correct `path` to your wordpress directory (`wp-cli` can only run from within the Wordpress Directory )
- Set the Schedule that you see fit.

---

```bash
# list all jobs

wp cron event list

+------------------------------------+---------------------+----------------------+------------+
| hook                               | next_run_gmt        | next_run_relative    | recurrence |
+------------------------------------+---------------------+----------------------+------------+
| ...                                |                     |                      |            |
| wp_site_health_scheduled_check     | 2025-11-05 00:55:50 | 6 days 23 hours      | 1 week     |
| ...                                |                     |                      |            |
+------------------------------------+---------------------+----------------------+------------+
```
