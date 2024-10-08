# CxFlow Batch Processor
This script will take an input of a project mapping csv and create tickets in batch mode for your Checkmarx projects. The project mapping will contain fields that will allow you to use different yml files to point to different Jira or bug tracker instances or you can also use environment variable to provide these values. 

Currently the projectMap.csv is meant to be stored in a repository which will be placed in a config folder. The script will pull the latest version of the csv every time it is run.

## Environment Variables
If you would like to use environment variables to provide the cxflow parameters, you will need to follow the format below. When using Environment Variables, all 3 environment variables need to be provided. *Please note this is all case sensivite*

Environment Variable | Variable Name Example | Value Example
---------------------|-----------------------|--------------
{Bug_Tracker}\_url\_{Bug_Tracker_Instance} |  Jira_url_cxmgl, github_url_cloudInstance | https://api.github.com/repos/
{Bug_Tracker}\_token\_{Bug_Tracker_Instance} | Jira_token_cxmgl, github_token_OnPrem | token1234
{Bug_Tracker}\_user\_{Bug_Tracker_Instance} | Jira_user_cxmgl, azure_user_CxAzure | user@email.com

- Note the {Bug_Tracker} and {Bug_Tracker_Instance} need to match the values from your projectMap.csv file 

## Project Map Contents

Project Map Columns | Description
--------------------|------------
Checkmarx_Project | Project name as seen in Checkmarx
Checkmarx_Team | The Checkmarx team that the given project belongs to
Bug_Tracker | Jira, GitLab, GitHub, Azure
Bug_Tracker_Instance | A labe for the given Bug_Track ex. OnPrem, Cloud, etc
Jira_Project * | Jira project key
Jira_Issue_Type * | issue type for ticket that will be opened 
Repo_Name ** | Name of repository
Branch ** | Repository branch
Namespace ** | Namespace for the repo/branch provided
Config | the relative file path to the yml file that you want to use for cxflow

"*" - Denotes this field is required if Bug_Tracker = Jira

"**" - Denotes this field is required if Bug_Tracker = GitLab, GitHub, Azure
