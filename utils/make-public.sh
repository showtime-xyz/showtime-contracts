#!/bin/sh

set -x

DEST_DIR=${1}

echo "copying to DEST_DIR=${DEST_DIR}"

if [ "${DEST_DIR}" = "" ]; then
  echo "usage: make-public.sh <destination directory>"
  exit 1
fi

if [ ! -d ${DEST_DIR} ]; then
  echo "ERROR: DEST_DIR=${DEST_DIR} does not exist"
  exit 1
fi

echo mkdir -p ${DEST_DIR}/contracts/utils

for f in ERC2981Royalties.sol ShowtimeMT.sol ShowtimeV1Market.sol utils/AccessProtected.sol utils/BaseRelayRecipient.sol ; do
    cp contracts/${f} ${DEST_DIR}/contracts/${f}
done


