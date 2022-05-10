#!/bin/bash

# Parameters
DATAMODEL_DIR=datamodel
EXTENSION_DIR=extension_qgep_sige
REGEN_PROD_DB=true
REGEN_COMP_DB=true
CHECK_DELTA_ONLY=false # TODO: CHECK MD5 values only
TXT_LOG_MODE=true # outputs a txt file log from PUM. Set to false for upgrade in order to interact with the prompt yes/no

# Disconnect users to free databases (before that manually create a copy of prod db named qgep_prod_copy)
psql -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'qgep_prod_copy';"
psql -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'pum_qgep_prod';"
psql -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'pum_qgep_comp';"
psql -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'pum_qgep_test';"

# Set or reset prod db
if $REGEN_PROD_DB
then
  psql -U sige -d postgres -c "DROP DATABASE IF EXISTS pum_qgep_prod;"
  psql -U sige -d postgres -c "CREATE DATABASE pum_qgep_prod WITH TEMPLATE qgep_prod_copy;"
fi

# Get some info about status in upgrade table, check especially old deltas with pending status
if $CHECK_DELTA_ONLY
then
  pushd $DATAMODEL_DIR
  pum info -p pum_qgep_prod -t qgep_sys.pum_info -d delta
  popd
fi

# Clean no longer needed tables (e.g damage_backup_20200826d)
psql -U sige -d pum_qgep_prod -c "DROP TABLE IF EXISTS qgep_od.damage_backup_20200826d;"
psql -U sige -d pum_qgep_prod -c "DROP TABLE IF EXISTS qgep_od.file_backup_20200826;"
psql -U sige -d pum_qgep_prod -c "DROP TABLE IF EXISTS qgep_od.maintenance_event_backup_20200826;"

# Remove qgep_export schema because export views have been moved from qgep_export to qgep_od schema
psql -U sige -d pum_qgep_prod -c "DROP VIEW IF EXISTS qgep_export.vw_export_reach;"
psql -U sige -d pum_qgep_prod -c "DROP VIEW IF EXISTS qgep_export.vw_export_wastewater_structure;"
psql -U sige -d pum_qgep_prod -c "DROP SCHEMA IF EXISTS qgep_export;"

# Drop extension SIGE views
pushd $EXTENSION_DIR
psql -U sige -d pum_qgep_prod -f "drop_views.sql"
popd

# Fix sige customisations syntaxes
if $REGEN_PROD_DB
then
  psql -U sige -d pum_qgep_prod -c "ALTER TABLE qgep_od.reach RENAME sige_batch_cleaning_id TO usr_batch_cleaning_id;" # do not forget to upgrade qgis project accordingly
  psql -U sige -d pum_qgep_prod -c "ALTER TABLE qgep_od.reach RENAME sige_batch_inspection_id TO usr_batch_inspection_id;" # do not forget to upgrade qgis project accordingly
  psql -U sige -d pum_qgep_prod -c "ALTER TABLE qgep_od.reach RENAME sige_collecting_pipe_id TO usr_collecting_pipe_id;" # do not forget to upgrade qgis project accordingly
fi

# Set or reset test db
psql -U sige -d postgres -c "DROP DATABASE IF EXISTS pum_qgep_test;"
psql -U sige -d postgres -c "CREATE DATABASE pum_qgep_test;"

# Set or reset comp db, then initialize it
if $REGEN_COMP_DB
then
  pushd $DATAMODEL_DIR
  psql -U sige -d postgres -c "DROP DATABASE IF EXISTS pum_qgep_comp;"
  psql -U sige -d postgres -c "CREATE DATABASE pum_qgep_comp;"
  unset PGSERVICE # because this variable can be read by db_setup.sh in dot space mode
  ./scripts/db_setup.sh -p pum_qgep_comp # initialize comp db (empty db, structure only)
  popd
fi

# PUM test-and-upgrade but wont upgrade anyway (prompt from user not available)
pushd  $DATAMODEL_DIR
if $TXT_LOG_MODE
then
  # here it wont upgrade anyway (prompt from user not available)
  pum test-and-upgrade -pp pum_qgep_prod -pt pum_qgep_test -pc pum_qgep_comp -t qgep_sys.pum_info -f qgep_prod_1_4_0.dump -d delta/ -i constraints views indexes -N public -N usr_cartoriviera -N qgep_sige --exclude-field-pattern 'usr_%' -v int SRID 2056 -x > ../pum_logs/pum_log_qgep_$(date +"%Y_%m_%d_%H_%M").txt
else
  # here PUM will prompt the user to enter y or n to upgrade
  pum test-and-upgrade -pp pum_qgep_prod -pt pum_qgep_test -pc pum_qgep_comp -t qgep_sys.pum_info -f qgep_1_4_0.dump -d delta/ -i constraints views indexes columns sequences triggers functions -N public -N usr_cartoriviera -N qgep_sige --exclude-field-pattern 'usr_%' -v int SRID 2056 -x
fi
popd

pushd $EXTENSION_DIR
. insert_views.sh pum_qgep_prod
popd
