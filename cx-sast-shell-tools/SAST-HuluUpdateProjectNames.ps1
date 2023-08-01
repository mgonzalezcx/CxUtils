param(
    [Parameter(Mandatory = $true)]
    [System.Uri]$sast_url,
    [String]$username,
    [String]$password,
    [Parameter(Mandatory = $true)]
    [String]$parentTeamPath,
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

#Get projects and teams list 
$teams = &"support/rest/sast/teams.ps1" $session
$projects = &"support/rest/sast/projects.ps1" $session

#Get all users that belong to one of the teams/subteams
$parentTeam = $teams | Where-Object {$_.fullname -eq "$parentTeamPath"}
if($parentTeam.count -eq 0){
    Write-Output "No team found with name $teamName"
    Exit
}
$targetTeams = $teams | Where-Object {$_.parentId -eq $parentTeam.id}

#Write-Output $targetTeams
$updateErrors = @()

$targetTeams |%{
    $teamId = $_.id
    $teamName = $_.name

    $targetProjects = $projects | Where-Object {$_.teamId -eq $teamId}

    $targetProjects | %{
        $projectId = $_.Id
        $owningTeam = $_.teamId
        $projectName = $_.name
        
        try{
            $gitDetails = &"support/rest/sast/getprojectgitdetails.ps1" $session $projectId
        
            #create the new project Name
            $repoName = $gitDetails.url.Substring($gitDetails.url.LastIndexOf('/')+1)
            $repoNameClean = $repoName.Substring(0,$repoName.LastIndexOf('.'))
            $repoBranch = $gitDetails.branch.Substring($gitDetails.branch.LastIndexOf('/')+1)
            $newProjectName = "$teamName" + "_" + $repoNameClean + "_" + "$repoBranch"

            Write-Output "current project Name: $projectName  ------   new project name: $newProjectName"

            $projectBody = @{
                name = $newProjectName;
                owningTeam = $owningTeam
            }
    
            ########
            # find all projects that have a duplicate name already existing and spit them out into a csv
            #######
            try{
                $result = &"support/rest/sast/updateProject.ps1" $session $projectId $projectBody
            }
            catch{
                Write-Output "Project Name: $newProjectName already exists"

                $csvEntry = New-Object -TypeName psobject -Property ([Ordered]@{
                    id = $projectId;
                    currentProjectName = $projectName;
                    newProjectName = $newProjectName
                    owningTeam = $teamName
                })
                
                $updateErrors += $csvEntry
            }
        }
        catch{
            Write-Output "No git settings for this projectId: $projectId"
        }
    }
}

$updateErrors | Export-Csv -Path './ProjectNameDuplicates.csv' -Delimiter ',' -Append -NoTypeInformation

