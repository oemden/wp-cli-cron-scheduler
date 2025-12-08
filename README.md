# wp-cli cron scheduler

## Wordpress Automatic Cron Trigger via `wp-cli`

**Context**

If you protect your website with **Cloudflare's Anti-bot WAF rules**, `wp-cron.php` jobs will be blocked, and standard wp cron jobs will just fail, unless you can do an IP Access rule, which is not possible on Free tier ( as far as I know ).

**Solution**

The Trick is to call `wp-cron` from `ssh`.

It works, but calling `php /path-to-wp-directory/www/wp-cron.php` from the cli will also fail: 

```
Error: WP-Cron spawn failed with error: cURL error 7: Failed to connect to your_wp_exemple.com port 443: Connection refused
```

So we'll then use `wp-cli` ( refer to this post on how to install it on OVH Mutualisé: ). 
`wp cron list` will work just fine, and calling a job too: `wp cron event run wp_site_health_scheduled_check` and, oh irony, `wp cron test` will fail.
Also `wp cron event run` can not run "all Jobs" like the `wp cron test` command does so we list cron jobs and run them in a loop.

n8n will run SSH command on a schedule (e.g., hourly) and trigger cron jobs.

### Unified Script: wp-cli-manager.sh ###

A single, unified script that manages WordPress cron jobs, plugin updates, and theme updates via `wp-cli`. It uses CLI flags to control execution mode and bypass Cloudflare's Anti-bot WAF rules.

**Key Features:**
- **Cron Management**: Run pending jobs (time-based) or all jobs (aggressive)
- **Plugin Updates**: Update active/inactive plugins with auto-update on/off filtering
- **Theme Updates**: Update active/inactive themes with auto-update on/off filtering
- **Safe Defaults**: Without flags, runs in safe mode (active + auto_update=on only)
- **Flexible Modes**: Combine flags for custom behavior or use shortcuts (-a/-A)

### n8n Automation

Automation is the whole idea. Automate the wp-cron jobs and bypass Cloudflare's anti-bot protection.

***Note:***
 Any Automation tool should work ( Make, Zapier ), I'll detail n8n workflow and link it soon.

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

- copy the script. If you want a ready to go option, place them in your web hosting Home directory under `/$HOME/Scripts` or anywhere you want and adapt the scripts and n8n workflow accordingly.

### n8n

- Install this workflow: [link Coming soon]()
- Create you ssh Credential
- Set the correct `path` to your wordpress directory ( ! `wp-cli` can only run from within the Wordpress Directory ! )
- Set the Schedule that you see fit.

---

## Usage

### Basic Syntax

```bash
./wp-cli-manager.sh [-w path | -W alias] [OPTIONS]
```

### WordPress Path (v0.4.0+)

The script needs to know which WordPress installation to work with. Three methods available:

#### Method 1: Explicit Path (`-w`)
```bash
./wp-cli-manager.sh -w /home/user/site1 -a
```

#### Method 2: Alias (`-W`)
Create `~/.wp-cli-manager-sites.env` with site aliases:
```bash
SITE1=/home/user/wordpress1
SITE2=/home/user/public_html
```

Then use:
```bash
./wp-cli-manager.sh -W SITE1 -a
```

#### Method 3: Current Directory (default)
```bash
cd /home/user/wordpress
./wp-cli-manager.sh -a
```

**Notes:**
- `-w` and `-W` are mutually exclusive
- If neither specified, uses current directory
- Each WordPress site can have its own `.wp-cli-manager.env` config

### CLI Flags

#### Cron Management
- `-c` : Run **pending** cron jobs only (checks `next_run_gmt` <= current time)
- `-C` : Run **ALL** cron jobs (ignores schedule - aggressive mode)

#### Plugin Management
- `-p` : Filter by **active** plugins only
- `-P` : Include **all** plugin statuses (active + inactive)
- `-u` : Filter by **auto-update ON** only
- `-U` : Include **all** auto-update statuses (on + off)

*Note: Plugin updates require **both** a status flag (`-p` or `-P`) AND an auto-update flag (`-u` or `-U`)*

#### Theme Management
- `-t` : Filter by **active** themes only
- `-T` : Include **all** theme statuses (active + inactive)
- `-o` : Filter by **auto-update ON** only
- `-O` : Include **all** auto-update statuses (on + off)

*Note: Theme updates require **both** a status flag (`-t` or `-T`) AND an auto-update flag (`-o` or `-O`)*

#### Shortcut Modes
- `-a` : **Safe mode** (default when no flags provided)
  - Equivalent to: `-c -p -u -t -o`
  - Runs pending crons + updates active plugins/themes with auto-update ON
- `-A` : **Aggressive mode**
  - Equivalent to: `-C -P -U -T -O`
  - Runs ALL crons + updates all plugins/themes regardless of status or auto-update setting

### Usage Examples

#### Default Behavior (No Path, No Flags)
```bash
cd /home/user/wordpress
./wp-cli-manager.sh
```
**Behavior**: Uses current directory, runs safe mode (`-a`)
- ✓ Pending cron jobs only
- ✓ Active plugins with auto-update ON
- ✓ Active themes with auto-update ON

#### Using Explicit Path
```bash
# Run pending crons on specific site
./wp-cli-manager.sh -w /home/user/site1 -c

# Safe mode on specific site
./wp-cli-manager.sh -w /home/user/site2 -a
```

#### Using Aliases
```bash
# Run aggressive mode on aliased site
./wp-cli-manager.sh -W SITE1 -A

# Update plugins only
./wp-cli-manager.sh -W SITE2 -p -u
```

#### Action Flags Examples
```bash
# Run only pending cron jobs
./wp-cli-manager.sh -w /path/to/wp -c

# Run ALL cron jobs (aggressive)
./wp-cli-manager.sh -w /path/to/wp -C

# Update active plugins with auto-update ON
./wp-cli-manager.sh -w /path/to/wp -p -u

# Update ALL plugins (active + inactive, auto-update ON/OFF)
./wp-cli-manager.sh -w /path/to/wp -P -U

# Combined: Pending crons + plugin updates
./wp-cli-manager.sh -w /path/to/wp -c -p -u

# Safe mode (explicit)
./wp-cli-manager.sh -w /path/to/wp -a
# Same as: -c -p -u -t -o

# Aggressive mode
./wp-cli-manager.sh -w /path/to/wp -A
# Same as: -C -P -U -T -O
```

### Configuration Files (v0.4.0+)

#### Site-Specific Configuration

Each WordPress installation can have its own `.wp-cli-manager.env` file in the WordPress root directory.

**Location**: `<wordpress-root>/.wp-cli-manager.env`

**Example `.wp-cli-manager.env`:**
```bash
# Site-specific configuration
# Optional: Feature toggles (default: true)
plugin_mgmt=true
theme_mgmt=true

# Optional: Run all crons by default (default: false)
run_all_crons=false
```

**Configuration Precedence**:
1. **CLI flags** (highest priority)
2. **`.wp-cli-manager.env`** file (in WordPress root)
3. **Script defaults** (lowest priority)

#### Sites Aliases Configuration

For managing multiple WordPress installations, create a sites file in your home directory.

**Location**: `~/.wp-cli-manager-sites.env`

**Example `~/.wp-cli-manager-sites.env`:**
```bash
# Define site aliases
SITE1=/home/user/wordpress1
SITE2=/home/user/public_html
SITE3=/home/user/websites/blog
```

**Usage:**
```bash
./wp-cli-manager.sh -W SITE1 -a
./wp-cli-manager.sh -W SITE2 -C
```

#### Available Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `plugin_mgmt` | `true` | Enable plugin management features |
| `theme_mgmt` | `true` | Enable theme management features |
| `run_all_crons` | `false` | Run all crons by default (currently informational) |

**Note**: Path configuration (`working_directory`, `wp_directory`) removed in v0.4.0. Use `-w`/`-W` flags instead.

### Behavior Matrix

| Flags | Crons | Plugins | Themes |
|-------|-------|---------|--------|
| *(none)* | Pending | Active + Auto-ON | Active + Auto-ON |
| `-a` | Pending | Active + Auto-ON | Active + Auto-ON |
| `-A` | ALL | All Status + All Auto | All Status + All Auto |
| `-c` | Pending | - | - |
| `-C` | ALL | - | - |
| `-p -u` | - | Active + Auto-ON | - |
| `-P -U` | - | All Status + All Auto | - |
| `-t -o` | - | - | Active + Auto-ON |
| `-T -O` | - | - | All Status + All Auto |
| `-c -p -u -t -o` | Pending | Active + Auto-ON | Active + Auto-ON |

### n8n Integration

There is a Workflow companion for n8n. Link coming soon.

When using with n8n SSH node:

**Execute Command Node:**

```bash
# Method 1: Using explicit path (-w)
./Scripts/wp-cli-manager.sh -w /home/username/public_html -a

# Method 2: Using site alias (-W)
# First create ~/.wp-cli-manager-sites.env with:
# PROD=/home/username/public_html
./Scripts/wp-cli-manager.sh -W PROD -a

# Method 3: cd first, then run
cd /home/username/public_html && ./Scripts/wp-cli-manager.sh -a
```

**Multi-Site Workflow Examples:**

```bash
# Workflow 1 - Site 1 (hourly pending crons)
./Scripts/wp-cli-manager.sh -W SITE1 -c

# Workflow 2 - Site 2 (daily safe updates)
./Scripts/wp-cli-manager.sh -W SITE2 -a

# Workflow 3 - Site 3 (weekly aggressive updates)
./Scripts/wp-cli-manager.sh -W SITE3 -A
```

**Schedule Examples:**
- **Hourly**: Run pending crons: `-c`
- **Daily**: Safe mode updates: `-a`
- **Weekly**: Aggressive mode: `-A`

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
