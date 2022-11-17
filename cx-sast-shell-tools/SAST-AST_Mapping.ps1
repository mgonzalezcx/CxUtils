param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [String]$username,
    [String]$password,
    [String]$fullTeamName,
    [Switch]$dbg
)

if(!$username){
    $credentials = Get-Credential -Credential $null
    $username = $credentials.UserName
    $password = $credentials.GetNetworkCredential().Password
}

. "support/debug.ps1"

setupDebug($dbg.IsPresent)

#Login and generate token
$session = &"support/rest/sast/loginV2.ps1" $sast_url $username $password -dbg:$dbg.IsPresent

#Get the list of projects that have git configured for source control
$allprojects = &"support/rest/sast/projects.ps1" $session
$teams = &"support/rest/sast/teams.ps1" $session
$allpresets = &"support/rest/sast/getpresets.ps1" $session
$allEngineConfigurations = &"support/rest/sast/getEngineConfigurations.ps1" $session


$csvDetails = @()
#set target projects
if(!$fullTeamName){
    $targetProjects = $allprojects
}
else{
    $targetTeamId = $teams | Where-Object {$_.fullName -eq $fullTeamName}
    $targetProjects = $allprojects | Where-Object {$_.teamID -eq $targetTeamId.id}
    #Write-Output $targetProjects
}
#Write-Output $targetProjects.id
#exit
#build list of project information and scm configuration
$targetProjects | %{
    $prjId = $_.id
    $prjName = $_.Name
    $prjTeamId = $_.teamID
    $prjTeam = $teams | Where-Object {$_.id -eq $prjTeamId}

    #Get the SCM settings if any
    try{
        $scmSettings = &"support/rest/sast/getprojectgitdetails.ps1" $session $prjId
        
        $projectUrl = $scmSettings.url;
        $projectgitBranch = $scmSettings.branch;
        
        Write-Debug $csvEntry
    }
    catch{
        Write-Debug "This project: $prjName , does not have git configuration"
        $projectUrl = '';
        $projectGitBranch = '';
    }

    #Get the project scan settings
    $projectSettings = &"support/rest/sast/getProjectSettings.ps1" $session $prjId
    $preset = $allpresets | Where-Object {$_.id -eq $projectSettings.preset.id}
    $engineConfig = $allEngineConfigurations | Where-Object {$_.id -eq $projectSettings.engineConfiguration.id}

    #Get last scan data
    try {
        $lastScan = &"support/rest/sast/scans.ps1" $session $prjId
    }
    catch {
        Write-Debug "This project has no scans"
        $lastScan = @{
            origin = "NONE";
            dateAndTime = @{
                finishedOn = "NONE"
            }
        }
    }
    

    $csvEntry = New-Object -TypeName psobject -Property ([Ordered]@{
        SAST_ProjectId = $prjId;
        SAST_ProjectName = $prjName;
        SAST_OwningTeam = $prjTeam.fullName;
        SAST_ProjectUrl = $projectUrl;
        SAST_ProjectGitBranch = $projectGitBranch;
        SAST_Preset = $preset.name;
        SAST_Last_Scan_Date = $lastScan.dateAndTime.finishecleardOn;
        SAST_ScanOrigin = $lastScan.origin;
        SAST_Engine_Configuration = $engineConfig.name;
        Cx1_ProjectId= '';
        Cx1_ProjectName = '';
        Cx1_AppName = '';
        Cx1_PresetName = '';
        Cx1_EnabledScanners = '';
        Cx1_Groups = '';
    })
    
    $csvDetails += $csvEntry
}

$csvDetails | Export-Csv -Path './SAST_CX1_Map.csv' -Delimiter ',' -Append -NoTypeInformation

