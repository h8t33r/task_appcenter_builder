# Set-ExecutionPolicy Unrestricted -Force
# [Environment]::GetEnvironmentVariable("apiTokenFA", "User")
# [Environment]::SetEnvironmentVariable("apiTokenRO", $_, "User")

function Register-Env-Varitables {
    $_apiTokenFA = Read-Host -Prompt "Enter Microsoft AppCneter full access authorize token"
    [Environment]::SetEnvironmentVariable("apiTokenFA", $_apiTokenFA, "User")

}

Register-Env-Varitables