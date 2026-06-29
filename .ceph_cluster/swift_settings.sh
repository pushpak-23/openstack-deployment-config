#!/bin/bash

set -euxo pipefail

NUM_OF_WHOS=$1
SERVICE_NAME="rgw.swift-rgw"
RGW_PORT="7480" 
sudo ceph orch apply rgw swift-rgw --port=7480 --placement="$NUM_OF_WHOS" # Default port results in port conflict and fails.
sudo ceph dashboard set-rgw-api-ssl-verify False
sudo ceph orch apply mgr compute03

if [[ $(grep -c ceph_rgw_keystone_password /etc/kolla/passwords.yml) -eq 1 ]]
then
    ceph_rgw_pass=$( grep ceph_rgw_keystone_password /etc/kolla/passwords.yml | cut -d':' -f2 | xargs )
    rgw_keystone_admin_user="ceph_rgw"
else
    ceph_rgw_pass=$( grep keystone_admin_password /etc/kolla/passwords.yml | cut -d':' -f2 | xargs )
    rgw_keystone_admin_user="admin"
fi

internal_url=$( grep ^kolla_internal_vip_address: /etc/kolla/globals.yml | cut -d':' -f2 | xargs )

# https://docs.ceph.com/en/latest/radosgw/keystone/#integrating-with-openstack-keystone
# https://www.spinics.net/lists/ceph-users/msg64137.html
# The "WHO" field in the "ceph config set" needs to be "client.rgw.default" NOT
# "client.radosgw.gateway". This can be verified by issuing "ceph config dump"
# Additionally, the name of all of the gateways need to be present.

WHO_IS=""
NUM_WHO_IS=$(echo "$WHO_IS" | wc -w)
while [[ "$NUM_WHO_IS" -lt "$NUM_OF_WHOS" ]]
do
    WHO_IS="$(sudo ceph auth ls | grep client.rgw | grep client)" || true
    echo "Waiting..."
    sleep 10
    NUM_WHO_IS=$(echo "$WHO_IS" | wc -w)
done

WHO_IS="client.rgw.default $WHO_IS"
echo "RGW CLIENTS: $WHO_IS"
#for WHO in $WHO_IS; do
#    sudo ceph config set "$WHO" rgw_keystone_api_version 3
#    sudo ceph config set "$WHO" rgw_keystone_url https://"$internal_url":5000
#    sudo ceph config set "$WHO" rgw_keystone_accepted_admin_roles "admin, ResellerAdmin"
#    sudo ceph config set "$WHO" rgw_keystone_accepted_roles "_member_, member, admin, ResellerAdmin"
#    sudo ceph config set "$WHO" rgw_keystone_implicit_tenants true 
#    sudo ceph config set "$WHO" rgw_keystone_admin_user "$rgw_keystone_admin_user"
#    sudo ceph config set "$WHO" rgw_keystone_admin_password "$ceph_rgw_pass"
#    sudo ceph config set "$WHO" rgw_keystone_admin_project service
#    sudo ceph config set "$WHO" rgw_keystone_admin_domain default
#    sudo ceph config set "$WHO" rgw_keystone_verify_ssl false
#    sudo ceph config set "$WHO" rgw_content_length_compat true
#    sudo ceph config set "$WHO" rgw_enable_apis "s3, swift, swift_auth, admin"
#    sudo ceph config set "$WHO" rgw_s3_auth_use_keystone true
#    sudo ceph config set "$WHO" rgw_enforce_swift_acls true
#    sudo ceph config set "$WHO" rgw_swift_account_in_url true
#    sudo ceph config set "$WHO" rgw_swift_versioning_enabled true
#    sudo ceph config set "$WHO" rgw_verify_ssl true
#done

for WHO in $WHO_IS; do
    echo "Configuring RGW client: $WHO"
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

# Redeploy your rgw daemon
sudo ceph orch restart rgw.swift-rgw
HOSTNAMES=$(sudo ceph orch host ls | grep -v HOST | awk '{print $1}' | tr '\n' ',')
sudo ceph orch apply mgr compute02 
