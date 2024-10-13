#!/bin/bash

set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install a package if it's not already installed
install_if_not_exists() {
    if ! command_exists "$1"; then
        echo "Installing $1..."
        sudo apt-get update
        sudo apt-get install -y "$1"
    else
        echo "$1 is already installed."
    fi
}

# Function to install certbot via snap
install_certbot() {
    if ! command_exists certbot; then
        echo "Installing certbot via snap..."
        sudo snap install --classic certbot
        sudo ln -s /snap/bin/certbot /usr/bin/certbot
    else
        echo "Certbot is already installed. Ensuring it's up to date..."
        sudo snap refresh certbot
    fi
}

# Function to download a file
download_file() {
    local url="$1"
    local output="$2"
    if command_exists curl; then
        sudo curl -sSL "$url" -o "$output"
    elif command_exists wget; then
        sudo wget -q -O "$output" "$url"
    else
        echo "Error: Neither curl nor wget is installed. Please install one of them."
        exit 1
    fi
}

# Main script
main() {
    read -p "Enter domain: " domain

    # Install certbot
    install_certbot

    # Stop Zimbra services
    echo "Stopping Zimbra services..."
    sudo su - zimbra -c 'zmcontrol stop'

    # Install certificate
    echo "Installing SSL certificate..."
    sudo certbot certonly --standalone -d "$domain"

    # Prepare Zimbra SSL directory
    zimbra_ssl_dir="/opt/zimbra/ssl/zimbra/commercial"
    sudo mkdir -p "$zimbra_ssl_dir"
    sudo cp "/etc/letsencrypt/live/$domain/privkey.pem" "$zimbra_ssl_dir/commercial.key"
    sudo chown zimbra:zimbra "$zimbra_ssl_dir/commercial.key"

    # Download and prepare chain certificates
    download_file "https://letsencrypt.org/certs/isrgrootx2.pem" "/tmp/ISRG-X2.pem"
    download_file "https://letsencrypt.org/certs/lets-encrypt-r3.pem" "/tmp/R3.pem"
    sudo cat "/tmp/R3.pem" "/tmp/ISRG-X2.pem" > "/etc/letsencrypt/live/$domain/chain.pem"

    # Verify certificate
    echo "Verifying certificate..."
    sudo su - zimbra -c "/opt/zimbra/bin/zmcertmgr verifycrt comm $zimbra_ssl_dir/commercial.key /etc/letsencrypt/live/$domain/cert.pem /etc/letsencrypt/live/$domain/chain.pem"

    # Install certbot-zimbra
    install_certbot_zimbra

    # Set up cron job for certificate renewal
    setup_cron_job

    echo "SSL installation completed successfully."
}

install_certbot_zimbra() {
    local version="0.7.11"
    local folder="/root/certbot-zimbra-$version"

    if [ ! -d "$folder" ]; then
        echo "Installing certbot-zimbra..."
        download_file "https://github.com/YetOpen/certbot-zimbra/archive/$version.tar.gz" "certbot-zimbra-$version.tar.gz"
        sudo tar xzf "certbot-zimbra-$version.tar.gz"
    fi

    cd "$folder" && sudo cp certbot_zimbra.sh /usr/local/bin/
    sudo /usr/local/bin/certbot_zimbra.sh -d

    echo "Restarting Zimbra services..."
    sudo su - zimbra -c 'zmcontrol restart'
}

setup_cron_job() {
    if ! sudo crontab -l | grep -q "/usr/bin/certbot" 2>/dev/null; then
        echo "Setting up cron job for certificate renewal..."
        (sudo crontab -l 2>/dev/null; echo "0 0 * * * /usr/bin/certbot renew --pre-hook \"/usr/local/bin/certbot_zimbra.sh -p\" --deploy-hook \"/usr/local/bin/certbot_zimbra.sh -d\"") | sudo crontab -
    else
        echo "Cron job for certificate renewal already exists."
    fi
}

# Run the main function
main
