l=( "add-user" "authorizer" "check-in" "check-out" "login" "qrcode-generator")
OLDPWD=$pwd
for d in ${l[@]}
do
    echo "Working dir $d;"
    name=$(echo "${d//-/_}" | awk -F "/" '{print $2}')
    echo "Zipping lambda $d"
    zipfile=$d/code.zip
    s3key=$d/code.zip
    rm -f $zipfile
    (cd $d/ && zip -r code.zip *)
    cd -
    # echo "Zip archive done"
    # bucket_name=af-lambda-code;
    # echo "Upload code.zip to s3 bucket: $bucket_name with key: $s3key"
    # aws s3api put-object --bucket $bucket_name --key $s3key --body $d/$name/code.zip --profile AF
done;