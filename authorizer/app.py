"""
   Copyright 2018 Amazon.com, Inc. and its affiliates. All Rights Reserved.

   Licensed under the MIT License. See the LICENSE accompanying this file
   for the specific language governing permissions and limitations under
   the License.
"""

import os
import re
import json
import logging
import base64
import hashlib
import boto3
import jwt


# Static code used for DynamoDB connection and logging
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])
log_level = os.environ['LOG_LEVEL']
log = logging.getLogger(__name__)
logging.getLogger().setLevel(log_level)

class InsufficientPermission(Exception):
    pass

def lambda_function(event, context):
    log.debug("Event: " + json.dumps(event))

    # Ensure the incoming Lambda event is for a token authorizer
    if event['type'] != 'REQUEST':
        log.error("Unauthorized")
        raise Exception('Unauthorized')

    try:
        # Set the principalId to the accountId making the authorizer call
        principalId = event['requestContext']['accountId']

        tmp = event['methodArn'].split(':')
        apiGatewayArnTmp = tmp[5].split('/')
        awsAccountId = tmp[4]

        policy = AuthPolicy(principalId, awsAccountId)
        policy.restApiId = apiGatewayArnTmp[0]
        policy.region = tmp[3]
        policy.stage = apiGatewayArnTmp[1]

        log.debug("%s" % policy)

        # Get authorization header in lowercase
        try:
            authorizationHeader = {k.lower(): v for k, v in event['headers'].items() if k.lower() == 'authorization'}
            token = authorizationHeader["authorization"].split()[1]
            token_key = event["stageVariables"]["HK"]
            log.debug("JWT Token: {}".format(token))
            jwt_token = jwt.decode(token, token_key, algorithm=['HS256'])
            roleHeader = {k.lower(): v for k, v in event['headers'].items() if k.lower() == 'role'}
            if roleHeader:
                allow = roleHeader["role"] == jwt_token["role"]
            else:
                allow = True
            if allow:
                policy.allowMethod(event['requestContext']['httpMethod'], event['path'])
            else:
                raise InsufficientPermission()
        except jwt.ExpiredSignatureError as ex:
            policy.denyMethod(event['requestContext']['httpMethod'], event['path'])
            log.info("Token expired")
        except jwt.InvalidSignatureError as ex:
            policy.denyMethod(event['requestContext']['httpMethod'], event['path'])        
            log.info("Invalid signature")
        except InsufficientPermission as ex:
            policy.denyMethod(event['requestContext']['httpMethod'], event['path'])
            log.info("Insufficient permission")
                
        authResponse = policy.build()
        log.debug("authResponse: " + json.dumps(authResponse))

        return authResponse
    except Exception:
        import traceback
        traceback.print_exc()
        raise Exception('Unauthorized')


class HttpVerb:
    GET = "GET"
    POST = "POST"
    PUT = "PUT"
    PATCH = "PATCH"
    HEAD = "HEAD"
    DELETE = "DELETE"
    OPTIONS = "OPTIONS"
    ALL = "*"


class AuthPolicy(object):
    awsAccountId = ""
    """The AWS account id the policy will be generated for. This is used to create the method ARNs."""
    principalId = ""
    """The principal used for the policy, this should be a unique identifier for the end user."""
    version = "2012-10-17"
    """The policy version used for the evaluation. This should always be '2012-10-17'"""
    pathRegex = "^[/.a-zA-Z0-9-\*]+$"
    """The regular expression used to validate resource paths for the policy"""

    """these are the internal lists of allowed and denied methods. These are lists
    of objects and each object has 2 properties: A resource ARN and a nullable
    conditions statement.
    the build method processes these lists and generates the approriate
    statements for the final policy"""
    allowMethods = []
    denyMethods = []

    restApiId = "*"
    """The API Gateway API id. By default this is set to '*'"""
    region = "*"
    """The region where the API is deployed. By default this is set to '*'"""
    stage = "*"
    """The name of the stage used in the policy. By default this is set to '*'"""

    def __init__(self, principal, awsAccountId):
        self.awsAccountId = awsAccountId
        self.principalId = principal
        self.allowMethods = []
        self.denyMethods = []

    def _addMethod(self, effect, verb, resource, conditions):
        """Adds a method to the internal lists of allowed or denied methods. Each object in
        the internal list contains a resource ARN and a condition statement. The condition
        statement can be null."""
        if verb != "*" and not hasattr(HttpVerb, verb):
            raise NameError("Invalid HTTP verb " + verb + ". Allowed verbs in HttpVerb class")
        resourcePattern = re.compile(self.pathRegex)
        if not resourcePattern.match(resource):
            raise NameError("Invalid resource path: " + resource + ". Path should match " + self.pathRegex)

        if resource[:1] == "/":
            resource = resource[1:]

        resourceArn = ("arn:aws:execute-api:" +
            self.region + ":" +
            self.awsAccountId + ":" +
            self.restApiId + "/" +
            self.stage + "/" +
            verb + "/" +
            resource)

        if effect.lower() == "allow":
            self.allowMethods.append({
                'resourceArn': resourceArn,
                'conditions': conditions
            })
        elif effect.lower() == "deny":
            self.denyMethods.append({
                'resourceArn': resourceArn,
                'conditions': conditions
            })

    def _getEmptyStatement(self, effect):
        """Returns an empty statement object prepopulated with the correct action and the
        desired effect."""
        statement = {
            'Action': 'execute-api:Invoke',
            'Effect': effect[:1].upper() + effect[1:].lower(),
            'Resource': []
        }

        return statement

    def _getStatementForEffect(self, effect, methods):
        """This function loops over an array of objects containing a resourceArn and
        conditions statement and generates the array of statements for the policy."""
        statements = []

        if len(methods) > 0:
            statement = self._getEmptyStatement(effect)

            for curMethod in methods:
                if curMethod['conditions'] is None or len(curMethod['conditions']) == 0:
                    statement['Resource'].append(curMethod['resourceArn'])
                else:
                    conditionalStatement = self._getEmptyStatement(effect)
                    conditionalStatement['Resource'].append(curMethod['resourceArn'])
                    conditionalStatement['Condition'] = curMethod['conditions']
                    statements.append(conditionalStatement)

            statements.append(statement)

        return statements

    def allowAllMethods(self):
        """Adds a '*' allow to the policy to authorize access to all methods of an API"""
        self._addMethod("Allow", HttpVerb.ALL, "*", [])

    def denyAllMethods(self):
        """Adds a '*' allow to the policy to deny access to all methods of an API"""
        self._addMethod("Deny", HttpVerb.ALL, "*", [])

    def allowMethod(self, verb, resource):
        """Adds an API Gateway method (Http verb + Resource path) to the list of allowed
        methods for the policy"""
        self._addMethod("Allow", verb, resource, [])

    def denyMethod(self, verb, resource):
        """Adds an API Gateway method (Http verb + Resource path) to the list of denied
        methods for the policy"""
        self._addMethod("Deny", verb, resource, [])

    def allowMethodWithConditions(self, verb, resource, conditions):
        """Adds an API Gateway method (Http verb + Resource path) to the list of allowed
        methods and includes a condition for the policy statement. More on AWS policy
        conditions here: http://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements.html#Condition"""
        self._addMethod("Allow", verb, resource, conditions)

    def denyMethodWithConditions(self, verb, resource, conditions):
        """Adds an API Gateway method (Http verb + Resource path) to the list of denied
        methods and includes a condition for the policy statement. More on AWS policy
        conditions here: http://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements.html#Condition"""
        self._addMethod("Deny", verb, resource, conditions)

    def build(self):
        """Generates the policy document based on the internal lists of allowed and denied
        conditions. This will generate a policy with two main statements for the effect:
        one statement for Allow and one statement for Deny.
        Methods that includes conditions will have their own statement in the policy."""
        if ((self.allowMethods is None or len(self.allowMethods) == 0) and
            (self.denyMethods is None or len(self.denyMethods) == 0)):
            raise NameError("No statements defined for the policy")

        policy = {
            'principalId': self.principalId,
            'policyDocument': {
                'Version': self.version,
                'Statement': []
            }
        }

        policy['policyDocument']['Statement'].extend(self._getStatementForEffect("Allow", self.allowMethods))
        policy['policyDocument']['Statement'].extend(self._getStatementForEffect("Deny", self.denyMethods))

        return policy
