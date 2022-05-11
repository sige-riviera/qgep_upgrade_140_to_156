# qgep_upgrade_140_to_156
Upgrade scripts for QGEP SIGE datamodel from version 1.4.0 to 1.5.6.

## Some definitions and notes for using PUM
See [qwat_upgrade_133_to_137 repository](https://github.com/sige-riviera/qwat_upgrade_133_to_137#some-definitions-and-notes-for-using-pum).

## Upgrade process step by step

### Install PUM
`sudo pip3 install pum`

### Prepare directory
`mkdir ~/sit/production/qgep_upgrade_140_to_156`

`cd ~/sit/production/qwat_upgrade_133_to_137

### Download QGEP datamodel
`git clone -b 1.5.6-1 git@github.com:QGEP/datamodel.git`

### Create a duplicate of production database to then avoid disconnecting users during upgrade tests
`psql -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'qgep_prod';"`

`psql -U sige -d postgres -c "CREATE DATABASE qgep_prod_copy WITH TEMPLATE qgep_prod;"`

### Check deltas from upgrades table
Edit sige_qgep_upgrade.sh script by setting CHECK_DELTA_ONLY=true then execute it:

`. sige_upgrade_qgep.sh`

### Lauch sige_qgep_upgrade.sh to analyse pum logs outputs
Edit sige_qgep_upgrade.sh script by setting CHECK_DELTA_ONLY=true, TXT_LOG_MODE=true then execute it:

`. sige_upgrade_qgep.sh`

### Lauch sige_qgep_upgrade.sh to upgrade pum_log_prod database
Edit sige_qgep_upgrade.sh script by setting CHECK_DELTA_ONLY=true, TXT_LOG_MODE=false then execute it:

`. sige_upgrade_qgep.sh`

At some point, the script should ask the user to apply deltas to pum_qwat_prod. Type in y or yes to proceed.

### Go to production and create an archive of old database version
`psql -U sige -d postgres -c "ALTER DATABASE qgep_prod RENAME TO qgep_prod_v140_20220510;"`

`psql -U sige -d postgres -c "CREATE DATABASE qgep_prod WITH TEMPLATE pum_qgep_prod;"`

`psql -U sige -d postgres -c "DROP DATABASE IF EXISTS qgep_prod_copy;"`

### Archive
Publish edited scripts, readme and logs on github sige-riviera to help future upgrades.
