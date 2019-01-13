# Microsoft AppCneter Full Access Authorize Token
$api_token = ""
# Microsoft AppCneter Read Only Token Authorize Token
$api_token_RO = "5945e988813567c0ef6537caea8f5f327d95c10d"

# Check Folders
function Create-Folders {
$log_folder = Test-Path $PSScriptRoot\logs -PathType Container
$builds_folder = Test-Path $PSScriptRoot\builds -PathType Container

    if ($log_folder -eq $FALSE) { mkdir $PSScriptRoot\logs }
    if ($builds_folder -eq $FALSE) { mkdir $PSScriptRoot\builds }
}

# Connect to AppCenter API and return response
function Get-API-Response {
Param ([string]$api_url, [string]$method)

    # Api URL
    $api_url = "https://api.appcenter.ms" + $api_url

    # Headers
    $headers = @{
        "Accept"="application/json"
        "X-API-Token"=$api_token_RO
    }

    # Init SSL connection
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # If Authorized successfully, get response
    $response = Invoke-WebRequest -Uri $api_url -Method $method -Headers $headers

    # $response
        if ($response.StatusCode -eq 200) {
            # Create JSON Content Section varitable
            $content_json = $response.Content | ConvertFrom-Json

            # Write to access log
            $data_time = Get-Date -Format g
            $data_time + " | method: " + $method + " | url: " + $api_url | out-file $PSScriptRoot\logs\access.log -append }
        else {
            "Error. Status Code: " + $response.StatusCode }

    return $content_json
}


Try {

Create-Folders

# Get current user info
$user_json = Get-API-Response -api_url "/v0.1/user" -method "Get"

# Get available apps
$apps_json = Get-API-Response -api_url "/v0.1/apps" -method "Get"

# Get available branches
$branches_json = Get-API-Response -api_url "/v0.1/apps/$($user_json.name)/$($apps_json.name)/branches" -method "Get"
$branches_json

$data_time = Get-Date -Format g
$data_time + " | " + $branches_json | out-file $PSScriptRoot\logs\builds.log -append
}

Catch {

$data_time = Get-Date -Format g
$exception_name = $_.Exception.GetType().Name
$exception_message = $_.Exception.Message

# Create Error string
$log_message = $data_time + " | " + $failed_item + " | " + $exception_message

# Print exception
$log_message

# Write to exceptions log
$log_message | out-file $PSScriptRoot\logs\exceptions.log -append

}

Finally {

$response = ""
$content_json = ""

}
