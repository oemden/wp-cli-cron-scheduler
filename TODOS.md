# Useful WP-CLI cron features:

## Updates:

wp plugin update
wp plugin update

- **Options:**
    - [] only "status" `active` {true,false}
    - [] only "auto_update" `on`  {true,false}

        - if 'status' is [ <only active {true,false}> ] && auto_update and 'update' <available> and auto-update <on>


- **Update For Later:**
    - wp core update - WordPress core updates # Risky Business for a starter
    - wp language core update - Translation updates # Risky Business for a starter
    - wp language plugin update --all # Risky Business for a starter


```bash
~/www $ wp plugin list
+-------------------------------------+----------+-----------+---------+----------------+-------------+
| name                                | status   | update    | version | update_version | auto_update |
+-------------------------------------+----------+-----------+---------+----------------+-------------+
| akismet                             | active   | none      | 5.5     |                | on          |
| all-in-one-wp-security-and-firewall | active   | none      | 5.4.3   |                | on          |
| wp-db-backup                        | active   | none      | 2.5.2   |                | on          |
| elementor                           | active   | none      | 3.32.5  |                | on          |
| grunion-ajax                        | inactive | none      | 1.3     |                | off         |
| grunion-contact-form                | inactive | none      | 2.3     |                | off         |
| responsive-addons-for-elementor     | active   | none      | 2.0.6   |                | on          |
| responsive-block-editor-addons      | active   | available | 2.1.3   | 2.1.4          | on          |
| safe-svg                            | active   | none      | 2.4.0   |                | on          |
| simple-download-monitor             | active   | none      | 4.0.2   |                | on          |
| simple-local-avatars                | active   | none      | 2.8.5   |                | on          |
| syntaxhighlighter                   | active   | none      | 3.7.2   |                | on          |
| timeline.js.wp-master               | inactive | none      | 0.1     |                | off         |
| updraftplus                         | active   | none      | 1.25.8  |                | on          |
| wp-optimize                         | active   | none      | 4.3.0   |                | off         |
| wp-2fa                              | active   | none      | 3.0.0   |                | on          |
| wp-mailto-links                     | active   | none      | 3.1.4   |                | on          |
| aios-firewall-loader                | must-use |           |         |                | off         |
+-------------------------------------+----------+-----------+---------+----------------+-------------+
~/www $ wp theme list
+---------------------+----------+--------+---------+----------------+-------------+
| name                | status   | update | version | update_version | auto_update |
+---------------------+----------+--------+---------+----------------+-------------+
| responsive-child-v2 | inactive | none   | 1.0.0   |                | off         |
| responsive-child    | active   | none   | 1.0.0   |                | off         |
| responsive          | parent   | none   | 6.2.7   |                | off         |
| twentytwentyfive    | inactive | none   | 1.3     |                | off         |
+---------------------+----------+--------+---------+----------------+-------------+
```

---

## Other TODOS:

- [ ] Add Wordpress Path as an .env variable ( www -> ${wp_directory} )

`cd  $HOME/www`



# For Later considerations

first usage is to have some cron runs blocked by Cloudfalre bots.

## Maintenance:

wp db optimize - Database optimization
wp transient delete --all - Clear expired transients
wp cache flush - Clear object cache
wp post delete $(wp post list --post_status=trash --format=ids) - Empty trash

## Database:

wp db export backup-$(date +%Y%m%d).sql - Database backups
wp db check - Database integrity check
wp post list --post_type=revision --format=count then wp post delete - Cleanup revisions

## Security/Cleanup:

wp comment spam --format=ids | xargs -I % wp comment delete % - Delete spam comments
wp user list --role=subscriber --field=ID | xargs -I % wp user delete % - Cleanup spam users (careful!)
wp media regenerate --yes - Regenerate thumbnails

## Monitoring:

wp plugin status - Check plugin health
wp core verify-checksums - Verify WP core integrity
wp cron event list - Monitor scheduled events

Most valuable: **db optimize, transient cleanup, core updates, db backups**
