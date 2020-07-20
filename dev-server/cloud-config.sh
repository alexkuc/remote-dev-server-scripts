#!/bin/bash
set -euo pipefail

########################
### SCRIPT VARIABLES ###
########################

# Name of the user to create and grant sudo privileges
USERNAME=developer

# Additional public keys to add to the new sudo user
OTHER_PUBLIC_KEYS_TO_ADD=(
    "{ssh-pubkey}"
)

# Timezone as displayed in /usr/share/zoneinfo
TIMEZONE=Europe/Athens

####################
### SCRIPT LOGIC ###
####################

# Add sudo user and grant privileges
useradd --create-home --shell "/bin/bash" --groups sudo,www-data "${USERNAME}"

# Enable password-less sudo for sudo user
echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/developer

# Create SSH directory for sudo user
home_directory="$(eval echo ~${USERNAME})"
mkdir --parents "${home_directory}/.ssh"

# Add additional provided public keys
for pub_key in "${OTHER_PUBLIC_KEYS_TO_ADD[@]}"; do
    echo "${pub_key}" >> "${home_directory}/.ssh/authorized_keys"
done

# Adjust SSH configuration ownership and permissions
chmod 0700 "${home_directory}/.ssh"
chmod 0600 "${home_directory}/.ssh/authorized_keys"
chown --recursive "${USERNAME}":"${USERNAME}" "${home_directory}/.ssh"

# Disable SSH for root
sed -i -e '/^PermitRootLogin/s/^.*$/PermitRootLogin no/' /etc/ssh/sshd_config
if sshd -t -q; then
    systemctl restart sshd
fi

# Bug 1659719:
# https://bugs.launchpad.net/snappy/+bug/1659719
mkdir -p "/home/${USERNAME}/repo/dist/"
chown --recursive "${USERNAME}:${USERNAME}" "/home/${USERNAME}/repo/"
sed -i -e 's#      \*) return;;#      \*) source /etc/profile\.d/apps\-bin\-path\.sh; cd ~/repo/; return;;#g' /home/developer/.bashrc

# Set timezone
timedatectl set-timezone ${TIMEZONE}

# Install Nginx
apt-get update
apt-get -y upgrade
apt-get -y install nginx

# Configure Nginx
SITECONFIG=/etc/nginx/sites-available/app.test
cat << 'EOF' > ${SITECONFIG}
server {
  listen 80;
  listen [::]:80;

  root /home/developer/repo/dist;
  index index.html home.html comparison.html application.html contact-us.html;
  server_name app.test www.app.test;

  # kill cache
  add_header Last-Modified $date_gmt;
  add_header Cache-Control 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0';
  if_modified_since off;
  expires off;
  etag off;

  #error_log /var/log/nginx/debug.log debug;
}
EOF
echo '127.0.0.1  app.test' >> /etc/hosts
ln -s ${SITECONFIG} /etc/nginx/sites-enabled/
service nginx reload

# Install Node
snap install node --classic --channel 14/stable

# Add exception for SSH and then enable UFW firewall
ufw allow OpenSSH
ufw allow "Nginx Full"
ufw allow 3000 # browsersync (livereload)
ufw allow 3001 # browsersync (admin ui)
ufw enable
