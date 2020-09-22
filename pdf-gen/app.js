
const { PDFDocument } = require("pdf-lib");
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
    
    try{
        var token = jwt.decode(event.stageVariables["HK"], jwt_token);
        console.debug(token);
        if (!token) token_error = true;
        if (token.error != null) token_error = true;
        const now = Math.floor(Date.now() / 1000)
        if (token.exp <= now) token_error = true;
        login_user = token.value["sub"];
        tenant = token.value["tenant"];
        fullname = token.value["name"]
    }catch(e){
        console.error(e);
        token_error = true;
    }

    if (token_error){
        return {
            "statusCode": 403,
            "body": JSON.stringify({ "message": "Unauthorized" })
            ,"headers": {
                "Access-Control-Allow-Origin": "*", 
                "Access-Control-Allow-Headers": "Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
                "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
            }
        }
    }

    var survey_fields = [
        "Febbre", "Tosse", "Gola", "Stanchezza", "Testa",
        "Muscoli", "Naso", "Nausea", "Vomito", "Gusto", "Congiuntivite",
        "Diarrea", "Covid", "Sospetti", "Familiari", "Conviventi", "Contatti"
    ];

    var params = {
        Bucket: "af-static", 
        Key: "autocertificazione_template.pdf"
       };
    const formPdfBytes = await s3.getObject(params).promise().then(function(data, err){
        console.debug(err, data);
        return data.Body;
    });

    const pdfDoc = await PDFDocument.load(formPdfBytes)
    const form = pdfDoc.getForm();
    
    // get profile data
    var params = {
        Key: {
         "login": {
           S: login_user
         }
        }, 
        TableName: "users"
    };

    await dynamodb.getItem(params).promise().then(function(data, err) {
        console.debug(err, data);
        var item = data["Item"];
        if(item){
            var isAdult = item["is_adult"]["N"] == 1;
            console.debug(isAdult);
            switch(isAdult){
                case false:
                    //console.log("working on child")
                    profile_values["Nome"] = item["parent"]["S"];
                    profile_values["NatoA"] = item["parent_town_of_birth"]["S"];
                    profile_values["Nascita"] = item["parent_birth_date"]["S"];
                    profile_values["Residenza"] = item["parent_address"]["S"];
                    profile_values["NomeFiglio"] = fullname
                    profile_values["NatoAFiglio"] = item["town_of_birth"]["S"];
                    profile_values["NascitaFiglio"] = item["birth"]["S"];
                    profile_values["ResidenzaFiglio"] = item["address"]["S"];
                    break;
                case true:
                    //console.log("working on parent")
                    profile_values["Nome"] = fullname
                    profile_values["NatoA"] = item["town_of_birth"]["S"];
                    profile_values["Nascita"] = item["birth"]["S"];
                    profile_values["Residenza"] = item["address"]["S"];
                    break;
                }
            
            // apply values
            try{
                profile_values["VisitaMedica"] = item["sport_medical_exam"]["S"]
            }catch(e){}
            try{
                profile_values["Compilazione"] = item["date_submit_survey"]["S"]
            }catch(e){}

            for (p in profile_values){
                console.debug("Get form textfield: " + p);
                var textfield = form.getTextField(p);
                console.debug("Form textfield: " + textfield);
                textfield.setText(profile_values[p]);
            }

            pdf_filename = login_user + '-' + profile_values["Compilazione"].replace("/","").replace("/","");
        }
    });
    
    // get survey data
    var params = {
        Key: {
         "login": {
           S: login_user
         }
        }, 
        TableName: "survey"
       };

    await dynamodb.getItem(params).promise().then(function(data, err) {
        console.debug(err, data)
        var item = data["Item"];
        if(item){
            for (var k=0; k<survey_fields.length; k++){
                var key = survey_fields[k].toLowerCase();
                var suffix = item[key]["S"];
                var checkbox = form.getCheckBox(survey_fields[k] + suffix);
                checkbox.check();
            }
        }
    });

    var params = {
        Key: {
         "code": {
           S: tenant
         }
        }, 
        TableName: "tenant"
    };

    await dynamodb.getItem(params).promise().then(function(data, err) {
        console.debug(err, data)
        var item = data["Item"];
        if(item){
            const tenantTextfield = form.getTextField("Societa");
            tenantTextfield.setText(item["description"]["S"]);
        }
    })

    const pdfBytes = await pdfDoc.save()

    // console.info(pdfBytes)
    var params = {
        Body: Buffer.from(pdfBytes.buffer),
        Bucket: "af-upload-docs",
        Key: "autocertificazioni/" + pdf_filename + ".pdf",
        ContentType: "application/pdf"
    }

    try {
        var res = await s3.putObject(params).promise();
        console.debug(res);

        var signed_url;
        await s3.getSignedUrlPromise('getObject', {
            Bucket: "af-upload-docs",
            Key: "autocertificazioni/" + pdf_filename + ".pdf"
        }).then(function(url) {
            console.log('The URL is', url);
            signed_url = url;
        }, function(err) { 
            console.error(err);
         });
    } catch (err) {
        console.debug(err);
        return;
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
