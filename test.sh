#/bin/bash

mode="release" # release or debug
./.build/$mode/coredataimport --structure Resources/Structures.xcdatamodeld --asset Resources/Assets.xcassets --output Resources

# todo: make a loop on hash/dico
table="EMPLOYES"
expected=11
count=$(sqlite3 Resources/Structures.sqlite "select count(*) FROM Z$table")
if [ $count -eq $expected ]; then
     echo "$count $table ok"
 else
     >&2 echo "expected $expected but receive $count for $table"
     exit 1
fi
table="ALL_TYPES"
expected=4
count=$(sqlite3 Resources/Structures.sqlite "select count(*) FROM Z$table")
if [ $count -eq $expected ]; then
     echo "$count $table ok"
 else
     >&2 echo "expected $expected but receive $count for $table"
     exit 1
fi
table="SERVICE"
expected=0
count=$(sqlite3 Resources/Structures.sqlite "select count(*) FROM Z$table")
if [ $count -eq $expected ]; then
     echo "$count $table ok"
 else
     >&2 echo "expected $expected but receive $count for $table"
     exit 1
fi
