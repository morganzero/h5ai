#!/usr/bin/env bash

msg() {
    echo "$1"
}
    
# Display environment variables
msg "Variables:"
msg -e "\t- PUID=${PUID}"
msg -e "\t- PGID=${PGID}"
msg -e "\t- TZ=${TZ}"
msg -e "\t- HTPASSWD=${HTPASSWD}"
msg -e "\t- HTPASSWD_USER=${HTPASSWD_USER}"
msg -e "\t- HTPASSWD_PW=${HTPASSWD_PW}"

# Combine configuration file paths into arrays
orig_files=( "/etc/nginx/conf.d/h5ai.conf" "/usr/share/h5ai/_h5ai" )
conf_files=( "/config/nginx/h5ai.conf" "/config/h5ai/_h5ai" )

msg "Making those config directories, easy peasy."
mkdir -p /config/{nginx,h5ai}

msg "Adding a dummy user to handle permissions like a pro."
groupadd -g "$PGID" abc  # Create group if not exists
useradd -u "$PUID" -U -d /config -s /bin/false -g "$PGID" abc

# Locations of configuration files
options_file="/private/conf/options.json"

msg "Let's check those Nginx config files, shall we?"
if [ ! -f "${conf_files[0]}" ]; then
    msg "Copy original setup files to /config folder..."
    cp -arf "${orig_files[0]}" "${conf_files[0]}"
else
    msg "User setup files found: ${conf_files[0]}"
fi

msg "Check configuration files for h5ai..."
if [ ! -d "${conf_files[1]}" ]; then
    msg "Copy original setup files to /config folder..."
    cp -arf "${orig_files[1]}" "${conf_files[1]}"
else
    msg "User setup files found: ${conf_files[1]}"

    mmsg "Just gonna see if h5ai got any updates, fingers crossed!"
    new_ver=$(awk 'NR==1{print $3}' "${orig_files[1]}$options_file" | tr -cd '[:digit:]')
    pre_ver=$(awk 'NR==1{print $3}' "${conf_files[1]}$options_file" | tr -cd '[:digit:]')
    if [ "$new_ver" -gt "$pre_ver" ]; then
        msg "New version detected. Make existing options.json backup file..."
        cp "${conf_files[1]}$options_file" "/config/$(date '+%Y%m%d_%H%M%S')_options.json.bak"

        msg "Remove existing h5ai files..."
        rm -rf "${conf_files[1]}"

        msg "Copy the new version..."
        cp -arf "${orig_files[1]}" "${conf_files[1]}"
    fi
fi
    
msg "Gotta set the right permissions for caching!"
chmod -R 777 "${conf_files[1]}/public/cache"
chmod -R 777 "${conf_files[1]}/private/cache"

# If a user wants to set htpasswd
if [ "$HTPASSWD" = "true" ]; then
    conf_htpwd="/config/nginx/.htpasswd"
    if [ ! -f "$conf_htpwd" ]; then
        msg "Create an authenticate account for h5ai website..."

        if [ -z "$HTPASSWD_PW" ]; then
            msg "Please enter a password for user $HTPASSWD_USER"
            read -s HTPASSWD_PW
            echo

            # Create a new htpasswd file with the user's entered password
            htpasswd -c "$conf_htpwd" "$HTPASSWD_USER" "$HTPASSWD_PW"
        else
            # Create a new htpasswd file with environment variables
            htpasswd -b -c "$conf_htpwd" "$HTPASSWD_USER" "$HTPASSWD_PW"
        fi
    else
        msg "User setup files found: $conf_htpwd"
    fi

    # Patch Nginx server instance
    if ! grep -q "auth" "${conf_files[0]}"; then
        patch -p1 "${conf_files[0]}" -i /h5ai.conf.htpasswd.patch
    fi
else
    if grep -q "auth" "${conf_files[0]}"; then
        msg "HTPASSWD not configured but Nginx server sets. Reverse the patch..."
        patch -R -p1 "${conf_files[0]}" -i /h5ai.conf.htpasswd.patch
    fi
fi
   
msg "Fixing ownership for Nginx and php-fpm, no biggie."
sed -i "s#user  nginx;.*#user  abc;#g" /etc/nginx/nginx.conf
sed -i "s#user = nobody.*#user = abc#g" /etc/php81/php-fpm.d/www.conf
sed -i "s#group = nobody.*#group = abc#g" /etc/php81/php-fpm.d/www.conf

msg "Time to claim ownership of those config files."
chown -R abc:abc /config

msg "Let's kick off supervisord!"
supervisord -c /etc/supervisor/conf.d/supervisord.conf
