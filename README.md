# Ruby Oauth Typhoeus Wrapper

This project provides a very simple wrapper example class which supports adding the Google ServiceAccount Oauth 2.0 
flow to Typheous requests, in a "transparent" way (ie, not noticed by the calling script).

## Citations

This project could not be possible without the wonderful work of the [Typhoeus Project](https://github.com/typhoeus/typhoeus).

## Usage

Currently, there is no gem, or unit tests, or anything that will help you work with this class, and there most likely 
will never be such a thing.  So, to use this code, simply copy/paste the class definition for OauthTyphoeus (available
in [oauth-test.rb](oauth-test.rb)) into your code, initialize it and then refer to the Typhoeus documentation for usage.
   
Here is a quick code sample, taken from the source, which uses the OauthTyphoeus class:
 
 ```ruby
# file contains the json downloaded from google's service accounts page.  We do have to add 4 fields to it though.
typhoeusClient = OauthTyphoeus.new( path_to_google_json_file ) 
# Note that httpClient now acts just like the examples from the Typhoeus project:
object_list_response = httpClient.get(
    "https://www.googleapis.com/storage/v1/b/$bucket$/o",
    followlocation: true,
    params: params,
    headers: { "Accept" => "application/json" }
)
if( object_list_response.code == 200 )
  object_list = JSON.parse(object_list_response.body)
  puts "Response: \n#{object_list.body}"
else
  puts "Error code"
end
 ```
 
In the above example, the only "trick" is that we have to tell the OauthTyphoeus instance where to find the google 
json file that you download when you create the service account.  The file should look something like this:

```json
{
  "type": "service_account",
  "project_id": "$pid",
  "private_key_id": "$privateKeyId",
  "private_key": "-----BEGIN PRIVATE KEY-----\nlots of stuff here\n-----END PRIVATE KEY-----\n",
  "client_email": "...@<account>.iam.gserviceaccount.com",
  "client_id": "...client id...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://accounts.google.com/o/oauth2/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/...",

  "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
  "access_uri": "https://www.googleapis.com/oauth2/v4/token",
  "audience" : "https://www.googleapis.com/oauth2/v4/token",
  "scopes" : "https://www.googleapis.com/auth/devstorage.full_control"

}
```

Note that we have to add 4 new fields to the JSON file:
* **grant_type** - This is the grant_type when requesting the token from the access_uri
* **access_uri** - Where we go to get the access token.  For some reason the token_uri and auth_uri from google didn't work.
* **audience** - A value google needs to work properly
* **scopes** - The *space delimited* list of auth scopes you are requesting access for.

 