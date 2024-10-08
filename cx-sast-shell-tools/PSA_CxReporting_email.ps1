param(
    [Parameter(Mandatory = $true)]
    [string]$recipient,
    [string]$xmlReport,
    [Switch]$dbg
)

###### Variables needed for this script to run ##################
#Sast credentials and urls
$sast_url  = ""
$reporting_url = ""
$username = ""
$password = ""
#smtp info
$smtpServer = ""
$fromEmail = ""
$smtpPort = 587
$emailPassword = ""
$emailSubject = 'Scan results from Checkmarx'
$emailBody = "Please find scan results attached generated by the CxReporting Service."

######################################################################

. "support/debug.ps1"
setupDebug($dbg.IsPresent)

#Login and generate token
$session = &"support/rest/cxreporting/authenticate.ps1" $sast_url $reporting_url $username $password -dbg:$dbg.IsPresent

#Grab the scanId
[xml]$scanReport = Get-Content -Path $xmlReport

#Generate the report
#TemplateIds
#1 for Scan Template Vulnerability Type oriented
#2 for Scan Template Result State oriented
#3 for Project Template
#4 for Single Team Template
#5 for Multi Teams Template

#build the report request as Json
$templateId = 2
$entityId = $scanReport.CxXmlResults.Scanid
$projectName = $scanReport.CxXmlResults.ProjectName
#Build out the request
$reportRequest = @{
    templateId = 2
    entityId   = @($entityId)
    filters    = @(
        @{
            type = 1
            excludedValues = @(
                'Medium',
                'Low',
                'Information'
                )
        },
        @{
            type = 2
            excludedValues = @(
                'To Verify'
                )
        }
    )
    outputFormat = "pdf"
}

#Write-Output $reportRequest | ConvertTo-Json -depth 10
#call apis
#create report request
$reportId = &"support/rest/cxreporting/generateReport.ps1" $session $reportRequest

#check for report status
$reportStatus = "NA"
while ($reportStatus.reportStatus -ne "Finished"){
    Start-Sleep -s 5
    try{
        $reportStatus = &"support/rest/cxreporting/getReportStatus.ps1" $session $reportId.reportId
    }
    catch{
        Write-Output "Report Failed to generate"
        Write-Output $reportStatus
        exit
    }

}

#download the report
$report = &"support/rest/cxreporting/getReport.ps1" $session $reportId.reportId $projectName

Write-Output $report

#send out email
$credentials = New-Object Management.Automation.PSCredential $fromEmail, ($emailPassword | ConvertTo-SecureString -AsPlainText -Force) #udpate with correct credentials
 Write-Output $param
$param = @{
    SmtpServer = $smtpServer
    Port = $smtpPort
    UseSsl = $true
    Credential  = $credentials
    From = $fromEmail
    To = $recipient
    Subject = $emailSubject
    Body = $emailBody
    Attachments = $report
}
 
Send-MailMessage @param

#cleanup files generated once they have been emailed
Remove-Item $report