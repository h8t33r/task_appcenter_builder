# Microsoft AppCneter Full Access Authorize Token
$api_token_FA = "457fb01333c32c88f493f5583641802470ae1105"
# Microsoft AppCneter Read Only Token Authorize Token
$api_token_RO = "5945e988813567c0ef6537caea8f5f327d95c10d"
# Application name
$app_name = "Damaten-CLub-App"

# Check Folders
function Create-Folders {
$log_folder = Test-Path $PSScriptRoot\logs -PathType Container
$builds_folder = Test-Path $PSScriptRoot\builds -PathType Container

    if ($log_folder -eq $FALSE) { mkdir $PSScriptRoot\logs }
    if ($builds_folder -eq $FALSE) { mkdir $PSScriptRoot\builds }
}

# Connect to AppCenter API and return response
function Get-API-Response {
Param ([string]$api_url, [string]$method, [hashtable]$body)

    # Api URL
    $api_url = "https://api.appcenter.ms" + $api_url

    # Headers
    $headers = @{
        "Accept" = "application/json"
        "X-API-Token" = $api_token_FA
    }

    # Init SSL connection
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # If Authorized successfully, get/post response
    if(!$body) {
        $response = Invoke-WebRequest -Uri $api_url -Method $method -Headers $headers
    }
    else {
        $headers.Add("Content-Type", "application/json")
        $response = Invoke-WebRequest -Uri $api_url -Method $method -Headers $headers -Body ($body | ConvertTo-Json)
    }

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

# Create Report function
function Create-Report {
Param ([string]$app_name)

    # Get available branches
    $raw_report_data = Get-API-Response -api_url "/v0.1/apps/$($user_json.name)/$($apps_json.name)/branches" -method "Get"

    # Init Date Format to REPORT file
    $report_name = "Report-" + (Get-Date -UFormat %Y.%m.%d-%H.%M.%S)

    # REPORT table head
    $table_head = "<style>
    table {border-collapse: collapse;}
    table, th, td {border: 1px solid #555;}
    td {width: 160px; padding: 2px;}
    </style>
    <h1>$($report_name)</h1>
    <table>
        <tr>
            <td><strong>Branch name</strong></td>
            <td><strong>Build status</strong></td>
            <td><strong>Duration</strong></td>
            <td><strong>Link to build logs</strong></td>
        </tr>`n" | out-file $PSScriptRoot\builds\$report_name.html -append

    # Generate REPORT body
    foreach($branch in $branches_json) {
        # Build Duration
        if ($branch.configured -ne $false) {
            $duration = New-TimeSpan -Start $branch.lastBuild.startTime -End $branch.lastBuild.finishTime
            $result = $branch.lastBuild.result
            # Get link to logfile
            $log_link = "<a href=`"https://appcenter.ms/download?url=/v0.1/apps/$($user_json.name)/$($app_name)/builds/$($branch.lastBuild.id)/downloads/logs`">Download log archive</a>"

        }
        else {
            $duration = "0"
            $result = "not configured"
            $log_link = "none"
        }


        # Table Row
        $row = "<tr>
            <td>$($branch.branch.name)</td>
            <td>$($result)</td>
            <td>$($duration)</td>
            <td>$($log_link)</td>
        </tr>`n"

        # Write to file
        $row | out-file $PSScriptRoot\builds\$report_name.html -append

    }

    # REPORT table footer
    $table_footer = "</table>" | out-file $PSScriptRoot\builds\$report_name.html -append

    return "Report created"
}

# Test Async Task
$async_task = {
Param([string]$sourceVersion, [bool]$debug, [string]$user_name, [string]$app_name, [string]$branch_name)
    # Body of build query
    $build_body = @{
        "sourceVersion" = $sourceVersion
        "debug" = $debug
    }
    $build_branch = Get-API-Response -api_url "/v0.1/apps/$($user_name)/$($app_name)/branches/$($branch_name)/builds" -method "Post" -body $build_body
    return $build_branch
}

Try {

# -----------------------
# Create /logs and /builds folders
Create-Folders

# Get current user info
$user_json = Get-API-Response -api_url "/v0.1/user" -method "Get"

# Get available apps (I have now 1 app, not array >_> )
$apps_json = Get-API-Response -api_url "/v0.1/apps" -method "Get"

# Get available branches
$branches_json = Get-API-Response -api_url "/v0.1/apps/$($user_json.name)/$($apps_json.name)/branches" -method "Get"

# Generate hashtable: branch_name = (sourseVersion, 40-char string)
[hashtable]$redy_to_build = @{}
foreach($row in $branches_json) {
    if ($row.configured -ne $false) {
        # Get branch source version to build 
        $sourceVersion = $row.branch.commit.url.Substring($row.branch.commit.url.Length -40, 40)

        # Add branch name and sourse version to Hashtable
        $redy_to_build.Add($row.branch.name, $sourceVersion)


         $build_body = @{
            "sourceVersion" = $sourceVersion
            "debug" = $true
         }
         # notStarted, inProgress
        $build_branch = Get-API-Response -api_url "/v0.1/apps/$($user_json.name)/$($apps_json.name)/branches/$($row.branch.name)/builds" -method "Post" -body $build_body
    }
}

# DEBUG | log to file
$redy_to_build | out-file $PSScriptRoot\logs\branches_avaible.txt -append

# TEST | Async Job
#Start-Job -ScriptBlock $async_task -ArgumentList "ac6c8e46065ecf6851436458ce621075b5fe8f0b", True, $user_json.name, $apps_json.name, "test_branch"

Start-Sleep -Seconds 300
Create-Report -app_name $apps_json.name

"End Script"
# -----------------------

}

Catch {

$data_time = Get-Date -Format g
$exception_name = $_.Exception.GetType().Name
$exception_message = $_.Exception.Message

# Create Error string
$log_message = $data_time + " | " + $exception_message

# Print exception
$log_message

# Write to exceptions log
$log_message | out-file $PSScriptRoot\logs\exceptions.log -append

}

Finally {

$response = $null
$content_json = $null
$branches_json = $null
$branch = $null
$file_dt = $null
$redy_to_build = $null
$build_body = $null

}