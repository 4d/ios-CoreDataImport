


#/bin/bash

#binary="/Users/phimage/perforce/depot/4eDimension/main/4DComponents/Internal User Components/4D Mobile App/Resources/scripts/coredataimport"

binary=$1

if [ -z "$binary" ]
then
    binary=".build/release/coredataimport"
fi

./test.sh "$binary" "$(pwd)/Resources"
./test.sh "$binary" "$(pwd)/Resources2"
./test.sh "$binary" "$(pwd)/Resources3"
