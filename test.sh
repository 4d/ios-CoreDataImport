#/bin/bash
binary=$1
folder=$2

if [ -z "$binary" ]
then
    binary=".build/release/coredataimport"
fi
if [ -z "$folder" ]
then
    folder="Resources"
fi

if [[ "$binary" != \/* ]]
then
    binary="./$binary"
fi

echo "$binary --verbosity 2 --structure $folder/Structures.xcdatamodeld --asset $folder/Assets.xcassets --output $folder"
"$binary" --verbosity 2 --structure "$folder/Structures.xcdatamodeld" --asset "$folder/Assets.xcassets" --output "$folder"

"$binary" check --structure "$folder/Structures.xcdatamodeld" --asset "$folder/Assets.xcassets" --output "$folder"

# todo: make a loop on hash/dico, maybe find in jSON
foldername=`basename $folder`

manifest="$folder/manifest.txt"
if [ -f "$manifest" ]; then
    while IFS=, read -r table expected
    do
        count=$(sqlite3 $folder/Structures.sqlite "select count(*) FROM Z$table")
        if [ $count -eq $expected ]; then
            echo "$count $table ok"
        else
            >&2 echo "expected $expected but receive $count for $table"
            exit 1
        fi
    done < "$manifest"

else
    echo "Database content of $folder is not tested"
    total=0
    tables=$(sqlite3 $folder/Structures.sqlite .tables)
    for table in $tables; do
        # show more info?
        count=$(sqlite3 $folder/Structures.sqlite "select count(*) FROM $table")
        echo "$table: $count"
        total=$(( $total + $count))
    done
    if [ $total -eq 0 ]; then
        >&2 echo "there is no record in database"
        exit 2
    fi   
fi
