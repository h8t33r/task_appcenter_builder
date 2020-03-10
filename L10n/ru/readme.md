# PowerShell Builder for Microsoft AppCenter
Version: 0.4

The script starts the application build process in the Microsoft Application
Center.

Script environment: Windows 10 / PowerShell 5.1

## Ссылки
[Microsoft AppCenter](https://appcenter.ms/)

[Microsoft AppCenter API](https://openapi.appcenter.ms/#/)

## Использование
1. For more security, the token is now stored in user environment variables.
Run register-token.ps1 and enter the 40-character token. Token generated in AppCenter user settings.

2. Введите имя приложения в builder.ps1.
```powershell
[string] $applicationName = "Example-Application"
```
3. запустите скрипт

## Документация

### До блока Try { }:

#### 1. Initialize variables

[string] $apiTokenFA - Full Access Authorize Token

[string] $apiTokenRO - Read Only Authorize Token

[string] $applicationName - Microsoft AppCneter - Application Name

[int] $sleepInSeconds - Build ineration checking time in seconds.

Also set the pathes for logs and report templates.

#### 2. Functions

##### Create-Folders { }

Check the availability of logs and reports directories . If absent - create
it.

##### Get-API-Response { }
1. Set AppCenter API root url
2. Set HTTP Headers varitable
3. Initiate SSL connection (TLS 1.2)
4. Choosing which method to use: GET of POST. If post - add "Content-Type"
5. Write the Log
6. Return JSON type Response

##### Build-Task { }
1. Use Try block
2. Run the application build process by calling the function
   Get-API-Response
3. Inside the loop, checking the build task has completed
4. Write HTML report row in file
5. Return result
6. Catch exceptions if they occur

### Inside Try { } block
1. Get the data of the user whose token was specified in [string]
   $apiTokenFA.
2. Get a list of application repository branches specified in [string] $
   applicationName
3. Set Report file name
4. In the foreach block we check that the branch is ready for building, get
   the sourceVersion from Url; form the body of the Post request, call the
   Build-Task

### Inside Catch { } block
To catch exceptions and write to the log.

### Inside Finally { } block
Reset some variables, to avoid errors when running the script in the same
environment PowerShell
