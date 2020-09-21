if [ -n "$1" ]; then
    l="$1"
else
    l=( "add-user" "authorizer" "check-in" "check-out" 
    "login" "logout" "refresh-token" "me"
    "update-me")
fi;

OLDPWD="$pwd"
for d in ${l[@]}
do
    echo "Working dir $d;"
    name=$(echo "${d//-/_}" | awk -F "/" '{print $2}')
    echo "Zipping lambda $d"
    zipfile=$d/build/code.zip
    #rm -rf $d/build
    rm -f $zipfile
    mkdir -p $d/build/
    cp $d/*.py $d/build/
    (
        cd $d/ 2> /dev/null && 
        pip3 install -r requirements.txt -t build/ --upgrade &&
        #[ -f "deps.txt" ] && cd build; while IFS= read -r line; do 7za x $line; done < deps.txt &&
        cd build && zip -r code.zip *
    )
    cd "$OLDPWD"
    # echo "Zip archive done"
    # bucket_name=af-lambda-code;
    # echo "Upload code.zip to s3 bucket: $bucket_name with key: $s3key"
    # aws s3api put-object --bucket $bucket_name --key $s3key --body $d/$name/code.zip --profile AF
done;

# pdf-gen
echo "Build pdf-gen function"
cp pdf-gen/*.js pdf-gen/build/;
cp -r pdf-gen/node_modules/ pdf-gen/build/node_modules/;
cd pdf-gen/build && zip -r code.zip * && cd -