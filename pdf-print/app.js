

const AWS = require("aws-sdk");
const jwt = require('json-web-token');

const s3 = new AWS.S3()
const dynamodb = new AWS.DynamoDB();

exports.handler = async (event) => {

    var tenant, fullname, pdf_filename;
    var login_user, token_error;
    var profile_values = {};

    var authorization = event["headers"]["Authorization"];
    var jwt_token = authorization.split("Bearer ")[1];

    try {
        var token = jwt.decode(event.stageVariables["HK"], jwt_token);
        console.debug(token);
        if (!token) token_error = true;
        if (token.error != null) token_error = true;
        const now = Math.floor(Date.now() / 1000)
        if (token.exp <= now) token_error = true;
        login_user = token.value["sub"];
        tenant = token.value["tenant"];
        fullname = token.value["name"]
    } catch (e) {
        console.error(e);
        token_error = true;
    }

    if (token_error) {
        return {
            "statusCode": 403,
            "body": JSON.stringify({ "message": "Unauthorized" })
            , "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
                "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
            }
        }
    }

    // get profile data
    var params = {
        Key: {
            "login": {
                S: login_user
            }
        },
        TableName: "users"
    };

    console.debug("get user", params);

    await dynamodb.getItem(params).promise().then(function (data, err) {
        console.debug(err, data);
        var item = data["Item"];
        if (item) {

            pdf_filename = login_user + '-' + item["date_submit_survey"]["S"].replace("/", "").replace("/", "");
        }
    });


    try {
        var signed_url;
        var params = {
            Bucket: process.env.BUCKET_NAME,
            Key: "autocertificazioni/" + pdf_filename + ".pdf"
        };
        await s3.headObject(params).promise();
        await s3.getSignedUrlPromise('getObject', params).then(function (url) {
            console.log('The URL is', url);
            signed_url = url;
        }, function (err) {
            console.error(err);
        });
    } catch (err) {
        console.debug(err);
        return {
            "statusCode": 200,
            "body": JSON.stringify({
                "url": "NULL"
            }),
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
                "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
            }
        }
    }

    console.log("success");
    return {
        "statusCode": 200,
        "body": JSON.stringify({
            "url": signed_url
        }),
        "headers": {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
            "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
        }
    }
}
