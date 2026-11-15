#!/bin/bash
# Copyright 2023.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -xe -o pipefail

export CELL_NAME=${CELL_NAME:?"Please specify a CELL_NAME variable."}

# A failing list_cells fails the job.
cells=$(nova-manage cell_v2 list_cells)

# NOTE(gibi): nova-manage should be enhanced upstream to get rid of this
# ugliness
# Note the "|" around the CELL_NAME, that is needed as a single line from
# nova-manage cell_v2 cell_list can match to multiple cells if the cell name
# is part of the line, e.g. as the user name of the DB URL
cell_uuid=$(echo "${cells}" | tr ' ' '|' | tr --squeeze-repeats '|' | { grep -e "^|$CELL_NAME|" || true; } | cut -d '|' -f 3)

if [ -z "${cell_uuid}" ]; then
    # Do not report a cell as not mapped if a mapping still uses its DB, e.g.
    # because the mapping got renamed.
    if echo "${cells}" | grep -qE "/nova_${CELL_NAME}([?[:space:]|]|$)"; then
        echo "Cell ${CELL_NAME} is not mapped by name but a mapping uses its DB"
        exit 1
    fi
    # The cell was never mapped, e.g. it never became ready, or its mapping
    # is already deleted by a previous run of this job.
    echo "Cell ${CELL_NAME} is not mapped, nothing to delete"
    exit 0
fi

nova-manage cell_v2 delete_cell --cell_uuid "${cell_uuid}"
