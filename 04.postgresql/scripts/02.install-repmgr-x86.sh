#!/bin/bash

# Color definitions
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'  # No Color

# 0. Function to print colored messages
print_colored() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# 1. check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   print_colored "$RED" "[Error] This script must be run as root"
   exit 1
fi

# 2. get the architecture of the system
arch=$(uname -m)
print_colored "$BLUE" "System architecture: $arch"


# 3. download and install repgmr RPM packages
# repmgr_15-5.3.3-1.rhel7.x86_64.rpm                 02-Jan-2024 18:05              284208
# repmgr_15-5.4.0-1.rhel7.x86_64.rpm                 02-Jan-2024 18:05              287604
# repmgr_15-5.4.1-1PGDG.rhel7.x86_64.rpm             02-Jan-2024 18:05              287784
# repmgr_15-devel-5.3.3-1.rhel7.x86_64.rpm           02-Jan-2024 18:05                8844
# repmgr_15-devel-5.4.0-1.rhel7.x86_64.rpm           02-Jan-2024 18:05                9332
# repmgr_15-devel-5.4.1-1PGDG.rhel7.x86_64.rpm       02-Jan-2024 18:05                9608
# repmgr_15-llvmjit-5.3.3-1.rhel7.x86_64.rpm         02-Jan-2024 18:05               21736
# repmgr_15-llvmjit-5.4.0-1.rhel7.x86_64.rpm         02-Jan-2024 18:05               22220
# repmgr_15-llvmjit-5.4.1-1PGDG.rhel7.x86_64.rpm     02-Jan-2024 18:05               22496
mkdir -p /usr/local/repmgr-5.5.0 && cd /usr/local/repmgr-5.5.0
if [[ -f repmgr-5.5.0-1.rhel7.x86_64.rpm ]]; then
    print_colored "$GREEN" "Repmgr 5.5.0 RPM package already downloaded"
else
    print_colored "$YELLOW" "Downloading Repmgr 5.5.0 RPM package..."
    wget https://download.postgresql.org/pub/repos/yum/15/redhat/rhel-7-x86_64/repmgr_15-5.4.1-1PGDG.rhel7.x86_64.rpm
fi

rpm -ivh repmgr-5.5.0-1.rhel7.x86_64.rpm

# 4. create user and set password for repmgr
createuser -s repmgr -h 127.0.0.1
createdb repmgr -O repmgr -h 127.0.0.1
psql -h 127.0.0.1 -c "ALTER USER repmgr WITH PASSWORD '123456';"
psql -h 127.0.0.1 -c "ALTER USER repmgr set search_path to repmgr, \"$user\", public";

# 5. add pg_hba.conf entry

echo "local repmgr repmgr md5" >> /data/5432/data/pg_hba.conf
echo "host repmgr repmgr 127.0.0.1/32 md5" >> /data/5432/data/pg_hba.conf
echo "host repmgr repmgr 10.0.0.0/24 md5" >> /data/5432/data/pg_hba.conf

echo "local replication repmgr md5" >> /data/5432/data/pg_hba.conf
echo "host replication repmgr 127.0.0.1/32 md5" >> /data/5432/data/pg_hba.conf
echo "host replication repmgr 10.0.0.0/24 md5" >> /data/5432/data/pg_hba.conf

# 6. modify repmgr.conf
mkdir -p /data/5432/repmgr/etc
cat > /data/5432/repmgr/etc/repmgr.conf << EOF
cluster = "repmgr_cluster"
node_id = 1
node_name = "node1"
conninfo = 'host=10.0.0.61 port=5432 user=repmgr password=123456 dbname=repmgr connect_timeout=2'
data_directory = '/data/5432/data'
pg_bindir = '/usr/local/pgsql/bin'
EOF

# mkdir -p /data/5432/repmgr/etc
# cat > /data/5432/repmgr/etc/repmgr.conf << EOF
# cluster = "repmgr_cluster"
# node_id = 2
# node_name = "node1"
# conninfo = 'host=10.0.0.62 port=5432 user=repmgr password=123456 dbname=repmgr connect_timeout=2'
# data_directory = '/data/5432/data'
# pg_bindir = '/usr/local/pgsql/bin'
# EOF


# mkdir -p /data/5432/repmgr/etc
# cat > /data/5432/repmgr/etc/repmgr.conf << EOF
# cluster = "repmgr_cluster"
# node_id = 3
# node_name = "node1"
# conninfo = 'host=10.0.0.63 port=5432 user=repmgr password=123456 dbname=repmgr connect_timeout=2'
# data_directory = '/data/5432/data'
# pg_bindir = '/usr/local/pgsql/bin'
# EOF

# 7. register node
repmgr -f /data/5432/repmgr/etc/repmgr.conf primary register 
repmgr -f /data/5432/repmgr/etc/repmgr.conf cluster show