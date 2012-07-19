#!/usr/bin/env bash

INPUT=$(hadoop dfsadmin -report | grep "Datanodes available")

ALIVE=$(echo $INPUT  | cut -d' ' -f 3);
TOTAL=$(echo $INPUT  | cut -d'(' -f 2 | cut -d' ' -f 1);
DEAD=$(echo $INPUT  | cut -d'(' -f 2 | cut -d' ' -f 3);

echo "Total:$TOTAL"
echo "Alive:$ALIVE"
echo "Dead:$DEAD"

