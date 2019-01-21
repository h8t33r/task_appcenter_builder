# ver. 0.3

# Microsoft AppCneter - Full Access Authorize Token
[string] $apiTokenFA = [Environment]::GetEnvironmentVariable("apiTokenFA", "User")

# Microsoft AppCneter - Read Only Authorize Token
[string] $apiTokenRO = ""

# Microsoft AppCneter - Application Name
[string] $applicationName = "Example-App"

[int] $sleepInSeconds = 10

# File paths
$logsPath = [IO.Path]::Combine($PSScriptRoot, 'logs')
$buildsPath = [IO.Path]::Combine($PSScriptRoot, 'builds')

$accessLogPath = [IO.Path]::Combine($PSScriptRoot, 'logs', 'access.log')
$exceptionsLogPath = [IO.Path]::Combine($PSScriptRoot, 'logs', 'exceptions.log')
$exceptionsTaskLogPath = [IO.Path]::Combine($PSScriptRoot, 'logs', 'exceptions_task.log')
$taskDebugLogPath = [IO.Path]::Combine($PSScriptRoot, 'logs', 'taskDebug.log')

# Report HEADER|FOOTER
$reportHeader = "<style>
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
    </tr>`n"
$reportFooter = "</table>"

# Check (and Create) Folders
function Create-Folders {
    [bool] $logFolder = Test-Path $logsPath -PathType Container
    [bool] $buildsFolder = Test-Path $buildsPath -PathType Container

    if ($logFolder -eq $FALSE) { mkdir $logsPath ; "Folder LOGS created"}
    if ($buildsFolder -eq $FALSE) { mkdir $buildsPath ; "Folder BUILDS created"}
}

# Connect to AppCenter API and return response
function Get-API-Response {
Param ([string]$APIUrl, [string]$method, [hashtable]$body)

    # API url path
    $APIUrl = "https://api.appcenter.ms" + $APIUrl

    # Headers
    [hashtable] $headers = @{
        "Accept" = "application/json"
        "X-API-Token" = $apiTokenFA
    }

    # Initiate SSL connection
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
            $dataTime + " | " + $APIUrl + "Error " | out-file $accessLogPath -append }

    return $contentJSON
}

# Builder function start task to build app in AppCenter and get status
function Build-Task {
Param ([string]$taskUserName, [string]$taskAppName, [string]$taskBranchName, [hashtable]$taskBuildBody, [string]$reportName)
    Try {
        $buildTaskResultJSON = Get-API-Response -APIUrl "/v0.1/apps/$($taskUserName)/$($taskAppName)/branches/$($taskBranchName)/builds" -method "Post" -body $taskBuildBody

        [string] $taskStatus = $buildTaskResultJSON.status
        [string] $taskBuildId = $buildTaskResultJSON.id

        do {
            $res = Get-API-Response -APIUrl "/v0.1/apps/$($taskUserName)/$($taskAppName)/builds/$($taskBuildId)" -method "Get"
            $taskStatus = $res.status

            Start-Sleep -Seconds $sleepInSeconds
        }
        until($taskStatus -eq "completed")
        # Status Codes: [notStarted, inProgress, complited]


        $durationRaw = New-TimeSpan -Start $res.startTime -End $res.finishTime
        $duration = $durationRaw.ToString().split(".")[0]

        $logLink = "https://appcenter.ms/download?url=/v0.1/apps/$($taskUserName)/$($taskAppName)/builds/$($res.id)/downloads/logs"

        [hashtable] $buildResult = @{
            "Branch" = $res.sourceBranch
            "Result" = $res.result
            "SourceVersion" = $res.sourceVersion
            "Duration" = $duration
            "Link" = $logLink
        }

        "<tr>
            <td>$($res.sourceBranch)</td>
            <td>$($res.result)</td>
            <td>$($duration)</td>
            <td><a href=`"$($logLink)`">Download log #$($res.id)</a></td>
         </tr>" | out-file $buildsPath\$reportName -append
        $res| out-file $taskDebugLogPath -append
        return $buildResult | ConvertTo-Json
    }
    Catch {
    $exceptionMessage = $_.Exception.Message
    $exceptionMessage | out-file $exceptionsTaskLogPath -append
    }
}

# Start
Try {
# Create /logs and /builds folders
Create-Folders

# Get current user info
$userJSON = Get-API-Response -APIUrl "/v0.1/user" -method "Get"

# Get available branches
$branchesJSON = Get-API-Response -APIUrl "/v0.1/apps/$($userJSON.name)/$($applicationName)/branches" -method "Get"

# Set Report file name
$reportName = "Report-" + (Get-Date -UFormat %Y.%m.%d-%H.%M.%S) + ".html"

# Queue block
#---------------------------------------------------------------
$reportHeader | out-file $buildsPath\$reportName -append
foreach($row in $branchesJSON) {
    # Check branch is configured
    if ($row.configured -ne $false) {
        # Get branch source version to build 
        $sourceVersion = $row.branch.commit.url.Substring($row.branch.commit.url.Length -40, 40)

        # Create Body for HTTP Request
        $buildBody = @{
            "sourceVersion" = $sourceVersion
            "debug" = $false }

        # Run task to build App
        $buildResult = Build-Task -taskUserName $userJSON.name -taskAppName $applicationName -taskBranchName $row.branch.name -taskBuildBody $buildBody -reportName $reportName
        $buildResult

    }
}
$reportFooter | out-file $buildsPath\$reportName -append
#---------------------------------------------------------------

"Script complete, see report in BUILDS folder"
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
$buildResult = $null
$buildResult = $null
$userJSON = $null
$branchesJSON = $null
}