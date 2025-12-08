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
./wp-cli-manager.sh [OPTIONS]
```

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

#### Default Behavior (No Flags)
```bash
./wp-cli-manager.sh
```
**Behavior**: Runs safe mode (`-a`)
- ✓ Pending cron jobs only
- ✓ Active plugins with auto-update ON
- ✓ Active themes with auto-update ON

#### Run Only Pending Cron Jobs
```bash
./wp-cli-manager.sh -c
```

#### Run ALL Cron Jobs (Aggressive)
```bash
./wp-cli-manager.sh -C
```

#### Update Active Plugins with Auto-Update ON
```bash
./wp-cli-manager.sh -p -u
```

#### Update ALL Plugins (Active + Inactive, Auto-Update ON/OFF)
```bash
./wp-cli-manager.sh -P -U
```

#### Update Active Themes with Auto-Update ON
```bash
./wp-cli-manager.sh -t -o
```

#### Combined: Pending Crons + Plugin Updates
```bash
./wp-cli-manager.sh -c -p -u
```

#### Combined: Pending Crons + All Plugin & Theme Updates
```bash
./wp-cli-manager.sh -c -P -U -T -O
```

#### Safe Mode (Explicit)
```bash
./wp-cli-manager.sh -a
```
Same as: `./wp-cli-manager.sh -c -p -u -t -o`

#### Aggressive Mode
```bash
./wp-cli-manager.sh -A
```
Same as: `./wp-cli-manager.sh -C -P -U -T -O`

### Environment Variables

The script supports configuration via environment variables and `.env` files (v0.3.1+).

#### Configuration Precedence

Variables are loaded in this order (highest priority wins):

1. **Environment variables** - **Highest Priority**
   - Shell profile (`.bash_profile`, `.bashrc`) and explicit `export` are **on the same level**
   - Script cannot distinguish between them - whichever is set last wins
   - Inline syntax: `VAR=value ./script.sh` also uses environment
2. **`.wp-cli-manager.env` file** - Only loads if variable NOT already in environment
3. **Script defaults** - Only for optional variables (plugin_mgmt, theme_mgmt, run_all_crons)

**Critical Variables** (REQUIRED):
- `working_directory` - Must be set via environment or `.env`
- `wp_directory` - Must be set via environment or `.env`

**Optional Variables** (have defaults):
- `plugin_mgmt="true"`
- `theme_mgmt="true"`
- `run_all_crons="false"`

#### Using `.wp-cli-manager.env` File

Create a `.wp-cli-manager.env` file in one of these locations:

1. **Script directory** (e.g., `Scripts/.wp-cli-manager.env`) - Recommended
2. **Current directory** (`./.wp-cli-manager.env`)
3. **Home directory** (`~/.wp-cli-manager.env`)

**Example `.wp-cli-manager.env`:**

```bash
# wp-cli-manager.sh Configuration File

# REQUIRED: Base directory (usually $HOME or absolute path)
working_directory=/home/myuser

# REQUIRED: WordPress subdirectory (relative to working_directory)
wp_directory=public_html

# OPTIONAL: Feature toggles
plugin_mgmt=true
theme_mgmt=true
run_all_crons=false
```

**Notes:**
- Comments start with `#`
- Values can be quoted or unquoted
- Environment variables already set override `.env` values
- First `.env` file found is used (see priority above)

#### Available Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `working_directory` | **REQUIRED** | Base directory path (e.g., `/home/myuser` or `$HOME`) |
| `wp_directory` | **REQUIRED** | WordPress subdirectory relative to working_directory |
| `plugin_mgmt` | `true` | Enable plugin management features |
| `theme_mgmt` | `true` | Enable theme management features |
| `run_all_crons` | `false` | Run all crons by default (currently informational) |

#### Usage Examples

**Method 1: Using `.env` file (Recommended)**

Create `Scripts/.wp-cli-manager.env`:
```bash
working_directory=/home/myuser
wp_directory=public_html
```

Then run:
```bash
./wp-cli-manager.sh -a
```

**Method 2: Export in shell (persistent for session)**

```bash
export working_directory="/home/myuser"
export wp_directory="public_html/wordpress"
./wp-cli-manager.sh -a
```

**Method 3: Inline (one-time)**

```bash
working_directory="/home/myuser" wp_directory="public_html" ./wp-cli-manager.sh -a
```

**Method 4: Shell profile (persistent across sessions)**

```bash
# Add to ~/.bash_profile or ~/.bashrc:
export working_directory="/home/myuser"
export wp_directory="public_html"

# Then run:
./wp-cli-manager.sh -a
```

**Method 5: n8n SSH node**

**Option A**: Use `.env` file (simpler)
- Create `.wp-cli-manager.env` in script directory
- Command: `./Scripts/wp-cli-manager.sh -a`

**Option B**: Set environment in n8n
- Environment field:
  ```
  working_directory=/home/myuser
  wp_directory=public_html
  ```
- Command field:
  ```bash
  ./Scripts/wp-cli-manager.sh -a
  ```

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
cd /home/username && ./Scripts/wp-cli-manager.sh -a
```

Or with environment variables:

```bash
working_directory="/home/username" wp_directory="public_html" ./Scripts/wp-cli-manager.sh -c
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
