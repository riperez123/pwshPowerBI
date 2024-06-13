$AzureConnection = (Connect-AzAccount -Identity).context
$ResourceGroup = "Azure resource Group name"
$UAMI = "User assigned Managed Identity"
$automationAccount = "Azure Automation account"
$AzureContext = Set-AzContext -SubscriptionName $AzureConnection.Subscription -DefaultProfile $AzureConnection
 
# Connects using the Managed Service Identity of the named user-assigned managed identity
    $identity = Get-AzUserAssignedIdentity -ResourceGroupName $ResourceGroup -Name $UAMI -DefaultProfile $AzureContext
 
    # validates assignment only, not perms
    $AzAutomationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroup -Name $automationAccount -DefaultProfile $AzureContext
    if ($AzAutomationAccount.Identity.UserAssignedIdentities.Values.PrincipalId.Contains($identity.PrincipalId)) 
        $AzureConnection = (Connect-AzAccount -Identity -AccountId $identity.ClientId).context
 
$myCredential = Get-AutomationPSCredential -Name 'runbook acct'
Connect-PowerBIServiceAccount -Credential $myCredential
 
"Get current date"
# $StartDate =(Get-Date).AddDays(-1)
# $EndDate = (Get-Date)
# $RetrieveDate = (Get-Date).AddDays(-1)
# $DateIterator = $RetrieveDate
 
$EndDate = (Get-Date -AsUTC).AddHours(-5)
$RetrieveDate = (Get-Date -AsUTC).AddDays(-1).AddHours(-5)
$DateIterator = $RetrieveDate
 
$RetrieveDate 
$EndDate
 
$storageAccName = "Azure Storage account name"
$sas_token = "SaS Token"
$container = "containerName"
$blob01 = "containerName\blobName" + "_" + $DateIterator.ToString('yyyyMMdd') + ".csv"
"set blob location"
 
while ($DateIterator -le $EndDate)
{
 
    "Define export path"
 
    $ActivityLogsPath = ".\blobName" + "_" + $DateIterator.ToString('yyyyMMdd') + ".csv"
   
    # Create File (Creating before makes headers first line of file)
    if(-not(Test-Path -Path $ActivityLogsPath))
    {
        Set-Content $ActivityLogsPath -Value "Id,RecordType,CreationTime,Operation,UserType,UserId,UserAgent,Activity,ItemName,WorkSpaceName,DatasetName,ReportName,DataflowId,DataflowName,DataflowType,WorkspaceId,CapacityId,CapacityName,AppName,ObjectId,DatasetId,ReportId,IsSuccess,ReportType,RequestId,ActivityId,AppReportId,DistributionMethod,ConsumptionMethod,DataConnectivityMode,RetrieveDate"
    }
 
    $DateIteratorYearStr = $DateIterator.ToString('yyyy')
    $DateIteratorMonthStr = $DateIterator.ToString('MM')
    $DateIteratorDayStr = $DateIterator.ToString('dd')
 
    $StartOfDay = $DateIteratorYearStr + '-' + $DateIteratorMonthStr + '-' + $DateIteratorDayStr + 'T00:00:00.000Z'
    $EndOfDay = $DateIteratorYearStr + '-' + $DateIteratorMonthStr + '-' + $DateIteratorDayStr + 'T23:59:59.999Z'
"$StartOfDay"
"$EndOfDay"
    $ActivityLogs = Get-PowerBIActivityEvent -StartDateTime $StartOfDay -EndDateTime $EndOfDay | ConvertFrom-Json
    "Get powerbi activity event command"
    $ActivityLogSchema = $ActivityLogs | `
        Select-Object Id,RecordType,CreationTime,Operation,UserType, `
          UserId,UserAgent,Activity,ItemName,WorkspaceName,DatasetName,ReportName,DataflowId,DataflowName,DataflowType, `
          WorkspaceId,CapacityId,CapacityName,AppName,ObjectId,DatasetId,ReportId,IsSuccess, `
          ReportType,RequestId,ActivityId,AppReportId,DistributionMethod,ConsumptionMethod,DataConnectivityMode, `
          @{Name="RetrieveDate";Expression={($RetrieveDate)}}
 
    $ActivityLogSchema | Export-Csv $ActivityLogsPath -Append
"Get childitem"
    $context = New-AzStorageContext -StorageAccountName $storageAccName -SasToken $sas_token 
    Get-ChildItem -Filter "*.csv" -Path $ActivityLogsPath -Recurse | ForEach-Object {Set-AzStorageBlobContent -Context $context -Container $container  -Blob $blob01  -File $_ -StandardBlobTier Cool -Force -AsJob }
    "output is done"
    $DateIterator = $DateIterator.AddDays(1)
    $blob01 = "PBIAuditLog\ActivityLogs" + "_" + $DateIterator.ToString('yyyyMMdd') + ".csv"
}
"Exit"