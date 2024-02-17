#!/bin/bash
set -eux

# download and install.
# renovate: datasource=github-releases depName=mailhog/MailHog
artifact_version='1.0.1'
artifact_url=https://github.com/mailhog/MailHog/releases/download/v$artifact_version/MailHog_linux_amd64
artifact_bin=/opt/mailhog/bin/MailHog
wget -qO /tmp/MailHog $artifact_url
install -d /opt/mailhog/bin
install -m 555 /tmp/MailHog /opt/mailhog/bin/MailHog
/opt/mailhog/bin/MailHog --version

# create the service and start it.
groupadd --system mailhog
adduser \
    --system \
    --disabled-login \
    --no-create-home \
    --gecos '' \
    --ingroup mailhog \
    --home /opt/mailhog \
    --shell /bin/bash \
    mailhog
install -d -o mailhog -g mailhog -m 750 /opt/mailhog
cat >/etc/systemd/system/mailhog.service <<'EOF'
[Unit]
Description=MailHog
After=network.target

[Service]
Type=simple
User=mailhog
Group=mailhog
ExecStart=/opt/mailhog/bin/MailHog -storage maildir -maildir-path /opt/mailhog/mail
WorkingDirectory=/opt/mailhog
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl enable mailhog
systemctl start mailhog

# configure the system to use mailhog as a smarthost.
# these anwsers were obtained (after installing nullmailer) with:
#   #sudo debconf-show nullmailer
#   sudo apt-get install debconf-utils
#   # this way you can see the comments:
#   sudo debconf-get-selections
#   # this way you can just see the values needed for debconf-set-selections:
#   sudo debconf-get-selections | grep -E '^nullmailer\s+' | sort
debconf-set-selections <<EOF
nullmailer nullmailer/defaultdomain string `hostname --domain`
nullmailer nullmailer/relayhost string localhost smtp --port=1025
nullmailer shared/mailname string `hostname --fqdn`
EOF
apt-get install -y nullmailer

# send test email.
sendmail root <<EOF
Subject: Test Email from `hostname --fqdn` at `date --iso-8601=seconds`

Sent from $0:$LINENO
EOF
