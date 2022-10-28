#!/bin/bash

# ./block_remover "first line to go" "first line to keep again" target_file

OPENER=$1
CLOSER=$2
TARGET_FILE=$3

echo "Target file: \"${TARGET_FILE}\""
echo "From \"${OPENER}\" to \"${CLOSER}\""

N_OPENER=`grep -n "${OPENER}" "${TARGET_FILE}" | awk -F: '{print $1}'`
N_CLOSER=`grep -n "${CLOSER}" "${TARGET_FILE}" | awk -F: '{print $1}'`
LINE_COUNT=`wc "${TARGET_FILE}" -l | awk '{print $1}'`

HEAD_N=$(( ${N_OPENER} - 1 ))
TAIL_N=$(( ${LINE_COUNT} - ${N_CLOSER} + 1))

echo "HEAD_N = ${HEAD_N}"
echo "TAIL_N = ${TAIL_N}"

# creation of the new file
PRE_BLOCK="${TARGET_FILE}.temp.pre"
POST_BLOCK="${TARGET_FILE}.temp.post"
NEW_FILE="${TARGET_FILE}.new"

head -n "${HEAD_N}" "${TARGET_FILE}" > "${PRE_BLOCK}"
tail -n "${TAIL_N}" "${TARGET_FILE}" > "${POST_BLOCK}"
cat "${PRE_BLOCK}" "${POST_BLOCK}" > "${NEW_FILE}"

rm "${PRE_BLOCK}" "${POST_BLOCK}"
mv "${NEW_FILE}" ${TARGET_FILE}

echo "${TARGET_FILE} altered."
