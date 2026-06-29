#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error when substituting.
# Set pipefail to cause a pipeline to return the exit status of the last command in the pipe that exited with a non-zero status.
set -euxo pipefail

NUM_OF_WHOS=$1
SERVICE_NAME="rgw.swift-rgw"
RGW_PORT="7480" # Ensure this matches your kolla-ansible/globals.yml setting

# Function to check if the RGW service exists
service_exists() {
    sudo ceph orch ls --service_name "$SERVICE_NAME" --format json | grep -q "\"service_name\": \"$SERVICE_NAME\""
}

# --- Service Deployment/Modification ---

# Check if the RGW service already exists
if service_exists; then
    echo "RGW service '$SERVICE_NAME' already exists. Applying configuration updates."
    # 'ceph orch apply' will update the service spec (e.g., placement, port) if it has changed.
    sudo ceph orch apply rgw swift-rgw --port="$RGW_PORT" --placement="$NUM_OF_WHOS"
else
    echo "RGW service '$SERVICE_NAME' does not exist. Creating and applying initial configuration."
    # Create the RGW service
    sudo ceph orch apply rgw swift-rgw --port="$RGW_PORT" --placement="$NUM_OF_WHOS"
fi

# Set dashboard RGW API SSL verification to False. This is often temporary for initial setup,
# but should be reviewed for production security practices.
echo "Setting Ceph Dashboard RGW API SSL verification to False..."
sudo ceph dashboard set-rgw-api-ssl-verify False

# Ensure mgr service is applied on compute03 (if it's a specific requirement)
echo "Applying mgr service on compute03..."
sudo ceph orch apply mgr compute03

# Determine RGW Keystone admin user and password from Kolla's passwords file
echo "Retrieving Keystone credentials from Kolla's passwords.yml..."
if [[ $(grep -c ceph_rgw_keystone_password /etc/kolla/passwords.yml) -eq 1 ]]
then
    ceph_rgw_pass=$( grep ceph_rgw_keystone_password /etc/kolla/passwords.yml | cut -d':' -f2 | xargs )
    rgw_keystone_admin_user="ceph_rgw"
else
    ceph_rgw_pass=$( grep keystone_admin_password /etc/kolla/passwords.yml | cut -d':' -f2 | xargs )
    rgw_keystone_admin_user="admin"
fi

# Get internal VIP address from Kolla's globals.yml
echo "Retrieving Kolla internal VIP address..."
internal_url=$( grep ^kolla_internal_vip_address: /etc/kolla/globals.yml | cut -d':' -f2 | xargs )

echo "Waiting for RGW clients to be registered..."
WHO_IS=""
NUM_WHO_IS=$(echo "$WHO_IS" | wc -w)
while [[ "$NUM_WHO_IS" -lt "$NUM_OF_WHOS" ]]
do
    # This grep relies on the format of 'ceph auth ls'.
    # A more robust way might be parsing 'ceph orch ls --service_type rgw -f json'
    # to get the exact daemon IDs (e.g., client.radosgw.swift-rgw.<hostname>.<id>).
    WHO_IS="$(sudo ceph auth ls | grep client.rgw | awk '/client.rgw/{print $1}' | tr '\n' ' ')" || true
    echo "Current RGW clients found: $WHO_IS (found $NUM_WHO_IS, expecting $NUM_OF_WHOS)"
    sleep 10
    NUM_WHO_IS=$(echo "$WHO_IS" | wc -w)
done

echo "Target RGW CLIENTS for configuration: $WHO_IS"

# Loop through each identified RGW client and set the configuration
for WHO in $WHO_IS; do
    echo "Configuring RGW client: $WHO"

    # Frontend Configuration
    # Note: Setting this via 'ceph config set' might be overridden by the orchestrator spec
    # if it's explicitly defined there. Ensure consistency.
    sudo ceph config set "$WHO" rgw_frontends "beast port=$RGW_PORT"
    # Keystone Integration Settings
    sudo ceph config set "$WHO" rgw_s3_auth_use_keystone true
    sudo ceph config set "$WHO" rgw_keystone_api_version 3
    sudo ceph config set "$WHO" rgw_keystone_url https://"$internal_url":5000
    sudo ceph config set "$WHO" rgw_keystone_admin_user "$rgw_keystone_admin_user"
    sudo ceph config set "$WHO" rgw_keystone_admin_password "$ceph_rgw_pass"
    sudo ceph config set "$WHO" rgw_keystone_admin_project service
    sudo ceph config set "$WHO" rgw_keystone_admin_domain default
    sudo ceph config set "$WHO" rgw_keystone_implicit_tenants true

    # Define roles required for administrative actions
    sudo ceph config set "$WHO" rgw_keystone_accepted_admin_roles "admin, ResellerAdmin"

    # Define roles allowed to interact with RGW via Keystone
    sudo ceph config set "$WHO" rgw_keystone_accepted_roles "_member_, member, admin, ResellerAdmin"

    # SSL Verification Settings
    # IMPORTANT: If you set rgw_keystone_verify_ssl true, you MUST ensure that the Keystone
    # SSL certificate is installed and trusted on all RGW nodes. If you are using a self-signed
    # certificate for Keystone and cannot install it, you might need to set this to 'false'
    # (less secure).
    sudo ceph config set "$WHO" rgw_keystone_verify_ssl false
    sudo ceph config set "$WHO" rgw_verify_ssl false

    # API and Feature Enabling
    sudo ceph config set "$WHO" rgw_enable_apis "s3, swift, swift_auth, admin"
    sudo ceph config set "$WHO" rgw_content_length_compat true
    sudo ceph config set "$WHO" rgw_enforce_swift_acls true
    sudo ceph config set "$WHO" rgw_swift_account_in_url true
    sudo ceph config set "$WHO" rgw_swift_versioning_enabled true
done

# Restart the RGW daemons for the new configuration to take effect
echo "Restarting RGW daemons to apply new configuration..."
sudo ceph orch restart "$SERVICE_NAME"

# This command seems out of place here unless it's an explicit requirement for your setup.
# If you are already managing MGR placement, this might be redundant or could override.
echo "Applying mgr service on compute02 (if required)..."
sudo ceph orch apply mgr compute02
