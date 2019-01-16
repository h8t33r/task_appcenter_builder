# ver. 0.2

# Microsoft AppCneter - Full Access Authorize Token
$apiTokenFA = "457fb01333c32c88f493f5583641802470ae1105"

# Microsoft AppCneter - Read Only Authorize Token
$apiTokenRO = "5945e988813567c0ef6537caea8f5f327d95c10d"

# Microsoft AppCneter - Application Name
$applicationName = "Damaten-CLub-App"

# File paths
$logsPath = [IO.Path]::Combine($PSScriptRoot, 'logs')
$accessLogPath = [IO.Path]::Combine($PSScriptRoot, 'logs', 'access.log')
$exceptionsLogPath = [IO.Path]::Combine($PSScriptRoot, 'logs', 'exceptions.log')
$avaibleBranchesLogPath = [IO.Path]::Combine($PSScriptRoot, 'logs', 'branches_avaible.log')

$buildsPath = [IO.Path]::Combine($PSScriptRoot, 'builds')
$buildsLogPath = [IO.Path]::Combine($PSScriptRoot, 'builds', 'builds.log')


# Check (and Create) Folders
function Create-Folders {
$logFolder = Test-Path $logsPath -PathType Container
$buildsFolder = Test-Path $buildsPath -PathType Container

    if ($logFolder -eq $FALSE) { mkdir $logsPath ; "Folder LOGS created"}
    if ($buildsFolder -eq $FALSE) { mkdir $buildsPath ; "Folder BUILDS created"}
}

# Connect to AppCenter API and return response
function Get-API-Response {
Param ([string]$APIUrl, [string]$method, [hashtable]$body)

    # API url path
    $APIUrl = "https://api.appcenter.ms" + $APIUrl

    # Headers
    $headers = @{
        "Accept" = "application/json"
        "X-API-Token" = $apiTokenFA
    }

    # Init SSL connection
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # If Authorized successfully, get/post response
    if(!$body) {
        $response = Invoke-WebRequest -Uri $APIUrl -Method $method -Headers $headers }
    else {
        $headers.Add("Content-Type", "application/json")
        $response = Invoke-WebRequest -Uri $APIUrl -Method $method -Headers $headers -Body ($body | ConvertTo-Json)
    }

    $dataTime = Get-Date -Format g

    # If status 200, get JSON response
        if ($response.StatusCode -eq 200) {
            # Create JSON Content Section varitable
            $contentJSON = $response.Content | ConvertFrom-Json

            # Write to access log
            $dataTime + " | method: " + $method + " | url: " + $APIUrl | out-file $accessLogPath -append }
        else {
            $erorrCode = "Error. Status Code: " + $response.StatusCode
            $dataTime + " | " + $APIUrl + " | " + $erorrCode | out-file $accessLogPath -append }

    return $contentJSON
}

# Create Report function
function Create-Report {
    # Get available branches
    $rawReportData = Get-API-Response -APIUrl "/v0.1/apps/$($userJSON.name)/$($applicationName)/branches" -method "Get"

    # Init Date Format to REPORT file
    $reportName = "Report-" + (Get-Date -UFormat %Y.%m.%d-%H.%M.%S)

    # REPORT table head
    $tableHead = "<style>
    table {border-collapse: collapse;}
    table, th, td {border: 1px solid #555;}
    td {width: 160px; padding: 2px;}
    </style>
    <h1>$($reportName)</h1>
    <table>
        <tr>
            <td><strong>Branch name</strong></td>
            <td><strong>Build status</strong></td>
            <td><strong>Duration</strong></td>
            <td><strong>Link to build logs</strong></td>
        </tr>`n" | out-file $PSScriptRoot\builds\$reportName.html -append

    # Generate REPORT body
    foreach($branch in $rawReportData) {
        # Build Duration
        if ($branch.configured -ne $false) {
            $duration = New-TimeSpan -Start $branch.lastBuild.startTime -End $branch.lastBuild.finishTime
            $result = $branch.lastBuild.result
            # Get link to logfile
            $logLink = "<a href=`"https://appcenter.ms/download?url=/v0.1/apps/$($userJSON.name)/$($applicationName)/builds/$($branch.lastBuild.id)/downloads/logs`">Download log archive</a>"

        }
        else {
            $duration = "0"
            $result = "not configured"
            $logLink = "none"
        }


        # Table Row
        $row = "<tr>
            <td>$($branch.branch.name)</td>
            <td>$($result)</td>
            <td>$($duration)</td>
            <td>$($logLink)</td>
        </tr>`n"

        # Write to file
        $row | out-file $PSScriptRoot\builds\$reportName.html -append

    }

    # REPORT table footer
    $table_footer = "</table>" | out-file $PSScriptRoot\builds\$reportName.html -append

    return "Report created"
}

# Test Async Task
$async_task = {
Param([hashtable]$taskBuildBody, [string]$taskUserName, [string]$taskAppName, [string]$taskBranchName)

    $buildBranch = Get-API-Response -APIUrl "/v0.1/apps/$($taskUserName)/$($taskAppName)/branches/$($taskBranchName)/builds" -method "Post" -body $taskBuildBody
    return $buildBranch
}

# Create /logs and /builds folders
Create-Folders

Try {

# Get current user info
$userJSON = Get-API-Response -APIUrl "/v0.1/user" -method "Get"

# Get available app / apps[]
#$appsJSON = Get-API-Response -APIUrl "/v0.1/apps" -method "Get"

# Get available branches
$branchesJSON = Get-API-Response -APIUrl "/v0.1/apps/$($userJSON.name)/$($applicationName)/branches" -method "Get"

# Generate hashtable: branch_name = (sourseVersion, 40-char string)

[int]$buildQueue = 2
[hashtable]$redyToBuild = @{}
foreach($row in $branchesJSON) {
    if ($row.configured -ne $false) {
        # Get branch source version to build 
        $sourceVersion = $row.branch.commit.url.Substring($row.branch.commit.url.Length -40, 40)

        # Add branch name and sourse version to Hashtable
        # $redyToBuild.Add($row.branch.name, $sourceVersion)
        $redyToBuild.Add($row.branch.name, $row.lastBuild.status)


         $buildBody = @{
            "sourceVersion" = $sourceVersion
            "debug" = $true
         }
        # notStarted, inProgress
        $build_branch = Get-API-Response -APIUrl "/v0.1/apps/$($userJSON.name)/$($applicationName)/branches/$($row.branch.name)/builds" -method "Post" -body $build_body

        # TEST | Async Job
        # Start-Job -ScriptBlock $async_task -ArgumentList $buildBody, $userJSON.name, $applicationName, $row.branch.name
    }
}

# DEBUG | log to file
$redyToBuild | out-file $PSScriptRoot\logs\branches_avaible.txt -append


Start-Sleep -Seconds 300

Create-Report

"End Script"
}

Catch {

$dataTime = Get-Date -Format g
$exceptionMessage = $_.Exception.Message

# Create Error string
$logMessage = $dataTime + " | " + $exceptionMessage

# Print exception
$logMessage

# Write to exceptions log
$logMessage | out-file $exceptionsLogPath -append

}

Finally {

$response = $null
$content_json = $null
$branchesJSON = $null
$branch = $null
$redyToBuild = $null
$build_body = $null

}