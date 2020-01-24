#/bin/bash
binary=$1
folder=$2

if [ -z "$mode" ]
then
    binary=".build/release/coredataimport"
fi
if [ -z "$folder" ]
then
    folder="Resources"
fi

./$binary --structure $folder/Structures.xcdatamodeld --asset $folder/Assets.xcassets --output $folder

# todo: make a loop on hash/dico, maybe find in jSON
if [ "$folder" == "Resources" ]; then

    table="EMPLOYES"
    expected=10
    count=$(sqlite3 $folder/Structures.sqlite "select count(*) FROM Z$table")
    if [ $count -eq $expected ]; then
         echo "$count $table ok"
     else
         >&2 echo "expected $expected but receive $count for $table"
         exit 1
    fi
    table="ALL_TYPES"
    expected=4
    count=$(sqlite3 $folder/Structures.sqlite "select count(*) FROM Z$table")
    if [ $count -eq $expected ]; then
         echo "$count $table ok"
     else
         >&2 echo "expected $expected but receive $count for $table"
         exit 1
    fi
    table="SERVICE"
    expected=0
    count=$(sqlite3 $folder/Structures.sqlite "select count(*) FROM Z$table")
    if [ $count -eq $expected ]; then
         echo "$count $table ok"
     else
         >&2 echo "expected $expected but receive $count for $table"
         exit 1
    fi
else
    echo "Database content is not tested"
    total=0
    tables=$(sqlite3 $folder/Structures.sqlite .tables)
    for table in $tables; do
        # show more info?
        count=$(sqlite3 $folder/Structures.sqlite "select count(*) FROM $table")
        echo "$table: $count"
        total=$total+$count
    done
    if [ $total -eq 0 ]; then
        >&2 echo "there is no record in database"
        exit 1
    fi   
fi
