#!/bin/bash

# Define pool names
POOLS=("volumes" "backups" "images" "metrics" "vms")
RBD_POOLS=("volumes" "images" "vms") # Pools to be initialized for RBD

# --- Create or resize pools to 128 PGs ---
# This loop checks if the pool exists. If it does, it resizes it.
# If it doesn't, it creates it.

echo "--- Creating or resizing pools to 128 PGs ---"
for POOL_NAME in "${POOLS[@]}"; do
  if ceph osd lspools | grep -wq "$POOL_NAME"; then
    echo "Pool '$POOL_NAME' already exists. Setting pg_num and pgp_num to 128."
    ceph osd pool set "$POOL_NAME" pg_num 128
    ceph osd pool set "$POOL_NAME" pgp_num 128
  else
    echo "Creating pool '$POOL_NAME' with 128 PGs."
    ceph osd pool create "$POOL_NAME" 128 128
  fi
done

# --- Ensure CRUSH rule exists ---
echo -e "\n--- Checking for 'hdd_rule' ---"
if ! ceph osd crush rule ls | grep -wq "hdd_rule"; then
  echo "CRUSH rule 'hdd_rule' not found. Creating it."
  # Assuming 'default' root, 'host' failure domain, and 'hdd' device class
  # If your CRUSH map differs, adjust this command accordingly.
  ceph osd crush rule create-replicated hdd_rule default host hdd
else
  echo "CRUSH rule 'hdd_rule' already exists."
fi

# Dump the CRUSH rule for verification
echo -e "\n--- Dumping 'hdd_rule' details ---"
ceph osd crush rule dump hdd_rule

# --- Set CRUSH rule for all pools ---
echo -e "\n--- Setting 'hdd_rule' for all pools ---"
for POOL_NAME in "${POOLS[@]}"; do
  ceph osd pool set "$POOL_NAME" crush_rule hdd_rule
  ceph osd pool get "$POOL_NAME" crush_rule
done

# --- Initialize RBD pools ---
echo -e "\n--- Initializing RBD pools ---"
for POOL_NAME in "${RBD_POOLS[@]}"; do
  echo "Initializing pool '$POOL_NAME' for RBD."
  # It's good practice to enable the 'rbd' application on the pool
  ceph osd pool application enable "$POOL_NAME" rbd --yes-i-really-mean-it
  rbd pool init "$POOL_NAME"
done

# --- Verify pool status ---
echo -e "\n--- Checking pool statistics ---"
for POOL_NAME in "${POOLS[@]}"; do
  ceph osd pool stats "$POOL_NAME"
done

echo -e "\nCeph pool setup and initialization script completed."
