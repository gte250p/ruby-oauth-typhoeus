#!/usr/bin/env ruby

require 'typhoeus'
require 'json'
require 'jwt'


#
#  Oauth Service Wrapper for Typhoeus
#    Performs "transparent" oauth integration and tested with google's ServiceAccount flow:
#       https://developers.google.com/identity/protocols/OAuth2ServiceAccount
#    Requires you call "new" given a path to the .json file downloaded from google's cloud permissions pages,
#    something like: https://console.cloud.google.com/permissions/projectpermissions?project=<projectId>
#
#    Note that you must provide the following 4 elements inside that JSON file to make it work:
#        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
#        "access_uri": "https://www.googleapis.com/oauth2/v4/token",
#        "audience" : "https://www.googleapis.com/oauth2/v4/token",
#        "scopes" : "https://www.googleapis.com/auth/devstorage.full_control"
#
class OauthTyphoeus

  def initialize(configJsonFilePath)
    contents = IO.read(configJsonFilePath)
    @configJson = JSON.parse(contents)
    @tokenCache = Hash.new
  end

  def method_missing(m, *args, &block)
    if( !isTokenValid() )
      renewToken()
    end
    Typhoeus.send(m, *addAuthorizationHeader(args), &block)
  end

  private

  def addAuthorizationHeader(args)
    newArgs = Array.new
    args.each do |arg|
      if( arg.is_a?(Hash) )
        if( arg.has_key?( :headers ) and arg[:headers].has_key?("Authorization") )
          raise "OauthTyphoeus Conflict - cannot modify existing 'Authorization' header.  Try submitting the request without it."
        elsif( arg.has_key?( :headers ) and !(arg[:headers].has_key?("Authorization")) )
          arg[:headers]["Authorization"] = @tokenCache[:token_type] + " " + @tokenCache[:access_token]
        else
          arg[:headers] = { "Authorization" => @tokenCache[:token_type] + " " + @tokenCache[:access_token] }
        end
      end
      newArgs.push(arg)
    end
    return newArgs
  end

  def renewToken()
    claim = buildClaim()
    rsa_private = OpenSSL::PKey::RSA.new @configJson["private_key"]
    token = JWT.encode claim, rsa_private, 'RS256'
    url = @configJson['access_uri']
    response = Typhoeus::post(
                url,
                followlocation: true,
                headers: { 'Accept' => "application/json", 'Content-Type'=> "application/x-www-form-urlencoded" },
                body: {'grant_type' => @configJson['grant_type'], 'assertion' => token}
    )

    responseJson = JSON.parse(response.body)
    @tokenCache[:claimExpiration] = claim["exp"]
    @tokenCache[:access_token] = responseJson["access_token"]
    @tokenCache[:token_type] = responseJson["token_type"]
    @tokenCache[:expires_in] = responseJson["expires_in"]

    puts "Successfully retrieved access_token[#{@tokenCache[:token_type]}: #{@tokenCache[:access_token]}]"
  end

  def buildClaim()
    claimHash = Hash.new
    claimHash["iss"] = @configJson["client_email"]
    claimHash["scope"] = @configJson["scopes"]
    claimHash["aud"] = @configJson["audience"]
    claimHash["iat"] = Time.new.to_i # Simply returns the time since the epoch.
    claimHash["exp"] = claimHash["iat"] + 3600 # 1 hour after iat (google hard coded)
    return claimHash
  end


  def isTokenValid
    if( @tokenCache[:access_token] == nil )
      return false
    else
      # Basically, it's valid if the time now is less than the expiration time (in millis since the epoch)
      return @tokenCache[:claimExpiration] > ( Time.new.to_i - 5 ) # The - 5 is to ensure we have ample time to execute the next request.
    end
  end

end


httpClient = OauthTyphoeus.new(ARGV[0])

params = { "maxResults" => "500", "pageToken" => pageToken }

puts "Out-going request: #{pageToken}"
object_list_response = httpClient.get(
    "https://www.googleapis.com/storage/v1/b/production_backup/o",
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
