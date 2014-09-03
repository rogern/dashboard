# dashboard

A dashboard for showing Jenkins build status, environment info, team calendar
events and metrics. Forked from https://github.com/edgeware/dashboard and uses
http://dashing.io/.

## Local development

 1. Edit `config.yml` with info for your setup.
 2. If using the metrics feature, add a `private_key.pem` to the repository
    root (client certificate is used to access the metrics).
 3. Run `bundle install` to install deps (use Ruby >= 2.0.0).
 4. Run `dashing start` and visit http://localhost:3030 in your browser.
