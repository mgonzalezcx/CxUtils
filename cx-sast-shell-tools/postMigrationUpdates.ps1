param(
    [string]$csv_path,
    [Switch]$dbg
)

####CxOne Variable######
$cx1Tenant=""
$PAT=""
$cx1URL="https://ast.checkmarx.net/api"
$cx1TokenURL="https://iam.checkmarx.net/auth/realms/$cx1Tenant"
$cx1IamURL="https://iam.checkmarx.net/auth/admin/realms/$cx1Tenant"
$csv_path="SAST_CX1_MapTest.csv"

. "support/debug.ps1"

setupDebug($dbg.IsPresent)


#Generate token for CxOne
$cx1Session = &"support/rest/cxone/apiTokenLogin.ps1" $cx1TokenURL $cx1URL "$cx1IamURL" $cx1Tenant $PAT

#Get list of CxOne projects
$cx1ProjectsResponse = &"support/rest/cxone/getprojects.ps1" $cx1Session
$cx1Projects = $cx1ProjectsResponse.projects

#Get list of CxOne groups
$cx1Groups = &"support/rest/cxone/getgroups.ps1" $cx1Session

$validationLine = 0
Import-Csv $csv_path | ForEach-Object {
    $validationLine++
    $projectName = $_.Cx1_ProjectName
    $groupName = $_.Cx1_Groups
    $repoBranch = $_.SAST_ProjectGitBranch
    $groupInfo = $cx1Groups | Where-Object {$_.name -eq $groupName}

    $projectData = $cx1Projects | Where-Object {$_.name -eq $projectName}

    $projectConfiguration = &"support/rest/cxone/getprojectconfig.ps1" $cx1Session $projectData.id

    #update project groups
    $projectDetails = @{
        name = $projectName
        groups = @($groupInfo.id)
        mainBranch = Split-Path $_.SAST_ProjectGitBranch -Leaf
    }

    $response = &"support/rest/cxone/updateproject.ps1" $cx1Session $projectData.id $projectDetails
    Write-Debug $response

    $projectConfigUpdates = @()
    #create entries for git url and branch
    $gitUrlSettings=@{
        key = "scan.handler.git.repository"
        name = "repository"
        category = "git"
        originLevel = "Project"
        value = $_.SAST_ProjectUrl
        valueType = "String"

    }

    $gitBranchSettings=@{
        key = "scan.handler.git.branch"
        name = "branch"
        category = "git"
        originLevel = "Project"
        value = Split-Path $_.SAST_ProjectGitBranch -Leaf
        valueType = "String"
    }

    #create entry for sast filters
    $fileExclusions = $_.SAST_FileExclusions.split(",");
    $folderExclusions = $_.SAST_FolderExclusions.split(",");
    $sastFilters = @()
    foreach($exclusion in $fileExclusions){
        $filter = "!"+$exclusion.trim()
        $sastFilters+=$filter
    }
    foreach($exclusion in $folderExclusions){
        $filter = "!"+$exclusion.trim()
        $sastFilters+=$filter
    }

    $sastFilterSettings=@{
        key = "scan.config.sast.filter"
        name = "folder/file filter"
        category = "sast"
        originLevel = "Project"
        value = ($sastFilters -join ",")
        valueType = "Block"
    }

    #create entry for preset
    $sastPresetSettings=@{
        key = "scan.config.sast.presetName"
        name = "presetName"
        category = "sast"
        originLevel = "Project"
        value = $_.Cx1_PresetName
        valueType = "List"
    }

    $projectConfigUpdates+= $gitUrlSettings
    $projectConfigUpdates+= $gitBranchSettings
    $projectConfigUpdates+= $sastFilterSettings
    $projectConfigUpdates+= $sastPresetSettings

    $response = &"support/rest/cxone/updateprojectconfiguration.ps1" $cx1Session $projectData.id $projectConfigUpdates


    #initiate scan for the project
    $gitScanRequest = @{
        type = "git"
        handler = @{
            branch = Split-Path $_.SAST_ProjectGitBranch -Leaf
            repoUrl = $_.SAST_ProjectUrl
        }
        project = @{
            id = $projectData.id
        }
        config = @(
            @{
                type = "sast"
            },
            @{
                type = "sca"
            }
        )
    }

    $response = &"support/rest/cxone/creategitscan.ps1" $cx1Session $gitScanRequest
}
