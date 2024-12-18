param(
    [Switch]$dbg
)

####CxOne Variables######
#Please update with the values for your environment and respective region
#update the url based on your login page. ex: https://ast.checkmarx.net, https://us.ast.checkmarx.net
#add an API key as the $PAT value
$cx1Tenant=""
$PAT=""
$cx1URL="https://ast.checkmarx.net/api"
$cx1TokenURL="https://iam.checkmarx.net/auth/realms/$cx1Tenant"
$cx1IamURL="https://iam.checkmarx.net/auth/admin/realms/$cx1Tenant"


. "support/debug.ps1"

setupDebug($dbg.IsPresent)

Add-Type -AssemblyName System.Web

#Generate token for CxOne
$cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT

#Get list of CxOne projects
$cx1ProjectsResponse = &"support/rest/cxone/getprojects.ps1" $cx1Session
$cx1Projects = $cx1ProjectsResponse.projects
$targetProjects = $cx1Projects | Where-Object { $_.repoId -ne $null}

$validationLine = 0

#Get list of SCMs registered
$scmList = &"support/rest/cxone/getScms.ps1" $cx1Session

#1. get scm repo scm repo settings
#2. grab the scm id
#3. build out the scan request
#       - need scm id, repo origin, project name, scanner types

$targetProjects | %{
    $branch = $null 
    $validationLine++
    $sleepCheck = $validationLine % 50
    if($sleepCheck -eq 0){
        start-sleep -Seconds 300
        $cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT
    }
    $projectName = $_.Name
    $projectId = $_.id
    $branch = $_.mainBranch
    
    Write-Debug $projectName
    Write-Debug $branch

    if($branch -ne ""){

        #Send the scan request
        &"support/rest/cxone/scaRecalcProject.ps1" $cx1Session $projectId $branch
    }

}