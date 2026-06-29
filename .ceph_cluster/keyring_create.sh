#!/bin/bash

# Define the path to the main Ceph config file
CEPH_CONF_SOURCE="/etc/ceph/ceph.conf"

# --- Setup for Cinder Backup ---
echo "--- Setting up Ceph configuration for Cinder Backup ---"
CINDER_BACKUP_DIR="/etc/kolla/config/cinder/cinder-backup"
mkdir -p "$CINDER_BACKUP_DIR"

echo "Copying ceph.conf to $CINDER_BACKUP_DIR"
cp "$CEPH_CONF_SOURCE" "$CINDER_BACKUP_DIR/ceph.conf"

echo "Generating client.cinder-backup keyring for pool 'backups'"
ceph auth get-or-create client.cinder-backup mon 'profile rbd' osd 'profile rbd pool=backups' mgr 'profile rbd pool=backups' > "$CINDER_BACKUP_DIR/ceph.client.cinder-backup.keyring"

echo "Generating client.cinder keyring for pools 'volumes', 'vms', 'images'"
ceph auth get-or-create client.cinder mon 'profile rbd' osd 'profile rbd pool=volumes, profile rbd pool=vms, profile rbd pool=images' mgr 'profile rbd pool=volumes, profile rbd pool=vms, profile rbd pool=images' > "$CINDER_BACKUP_DIR/ceph.client.cinder.keyring"

echo "Removing tabs from copied files in $CINDER_BACKUP_DIR"
sed -i $'s/\t//g' "$CINDER_BACKUP_DIR/ceph.conf"
sed -i $'s/\t//g' "$CINDER_BACKUP_DIR/ceph.client.cinder.keyring"
sed -i $'s/\t//g' "$CINDER_BACKUP_DIR/ceph.client.cinder-backup.keyring"

# --- Setup for Cinder Volume ---
echo -e "\n--- Setting up Ceph configuration for Cinder Volume ---"
CINDER_VOLUME_DIR="/etc/kolla/config/cinder/cinder-volume"
mkdir -p "$CINDER_VOLUME_DIR"

echo "Copying ceph.conf to $CINDER_VOLUME_DIR"
cp "$CEPH_CONF_SOURCE" "$CINDER_VOLUME_DIR/ceph.conf"

echo "Generating client.cinder keyring (ensuring presence for cinder-volume)"
# This command will retrieve the existing key if it was created above
ceph auth get-or-create client.cinder > "$CINDER_VOLUME_DIR/ceph.client.cinder.keyring"

echo "Removing tabs from copied files in $CINDER_VOLUME_DIR"
sed -i $'s/\t//g' "$CINDER_VOLUME_DIR/ceph.conf"
sed -i $'s/\t//g' "$CINDER_VOLUME_DIR/ceph.client.cinder.keyring"

# --- Setup for Glance ---
echo -e "\n--- Setting up Ceph configuration for Glance ---"
GLANCE_DIR="/etc/kolla/config/glance"
mkdir -p "$GLANCE_DIR"

echo "Copying ceph.conf to $GLANCE_DIR"
cp "$CEPH_CONF_SOURCE" "$GLANCE_DIR/ceph.conf"

echo "Generating client.glance keyring for pools 'volumes', 'images'"
ceph auth get-or-create client.glance mon 'profile rbd' osd 'profile rbd pool=volumes, profile rbd pool=images' mgr 'profile rbd pool=volumes, profile rbd pool=images' > "$GLANCE_DIR/ceph.client.glance.keyring"

echo "Removing tabs from copied files in $GLANCE_DIR"
sed -i $'s/\t//g' "$GLANCE_DIR/ceph.conf"
sed -i $'s/\t//g' "$GLANCE_DIR/ceph.client.glance.keyring"

# --- Setup for Nova ---
echo -e "\n--- Setting up Ceph configuration for Nova ---"
NOVA_DIR="/etc/kolla/config/nova"
mkdir -p "$NOVA_DIR"

echo "Copying ceph.conf to $NOVA_DIR"
cp "$CEPH_CONF_SOURCE" "$NOVA_DIR/ceph.conf"

echo "Generating client.cinder keyring for Nova (as Nova often uses Cinder's keyring for RBD access)"
# Nova compute nodes need access to Ceph to boot VMs from volumes or directly from Ceph.
# Kolla-Ansible documentation often suggests using the client.cinder keyring for this purpose.
ceph auth get-or-create client.cinder > "$NOVA_DIR/ceph.client.cinder.keyring"

echo "Removing tabs from copied files in $NOVA_DIR"
sed -i $'s/\t//g' "$NOVA_DIR/ceph.conf"
sed -i $'s/\t//g' "$NOVA_DIR/ceph.client.cinder.keyring"

# --- Setup for Gnocchi ---
echo -e "\n--- Setting up Ceph configuration for Gnocchi ---"
GNOCCHI_DIR="/etc/kolla/config/gnocchi"
mkdir -p "$GNOCCHI_DIR"

echo "Copying ceph.conf to $GNOCCHI_DIR"
cp "$CEPH_CONF_SOURCE" "$GNOCCHI_DIR/ceph.conf"

echo "Generating client.gnocchi keyring for pool 'metrics'"
# Gnocchi primarily uses the 'metrics' pool for its backend storage.
ceph auth get-or-create client.gnocchi mon 'profile rbd' osd 'profile rbd pool=metrics' mgr 'profile rbd pool=metrics' > "$GNOCCHI_DIR/ceph.client.gnocchi.keyring"

echo "Removing tabs from copied files in $GNOCCHI_DIR"
sed -i $'s/\t//g' "$GNOCCHI_DIR/ceph.conf"
sed -i $'s/\t//g' "$GNOCCHI_DIR/ceph.client.gnocchi.keyring"

echo -e "\nCeph client configuration for Kolla-Ansible services completed."
