#!/bin/bash

set -o errexit
cd `dirname $0`

eval `./admin/ShowDBDefs`

./admin/psql READWRITE < ./admin/sql/updates/20110617-pos_edits_pending.sql

echo `date` : Merging duplicate tracklists
./admin/psql READWRITE < ./admin/sql/updates/20110602-merge-duplicate-tracklists.sql

echo `date` : Done

# eof
