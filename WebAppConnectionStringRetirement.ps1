<#
.NOTES
    THIS CODE-SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED 
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR 
    FITNESS FOR A PARTICULAR PURPOSE.

    This sample is not supported under any Microsoft standard support program or service. 
    The script is provided AS IS without warranty of any kind. Microsoft further disclaims all
    implied warranties including, without limitation, any implied warranties of merchantability
    or of fitness for a particular purpose. The entire risk arising out of the use or performance
    of the sample and documentation remains with you. In no event shall Microsoft, its authors,
    or anyone else involved in the creation, production, or delivery of the script be liable for 
    any damages whatsoever (including, without limitation, damages for loss of business profits, 
    business interruption, loss of business information, or other pecuniary loss) arising out of 
    the use of or inability to use the sample or documentation, even if Microsoft has been advised 
    of the possibility of such damages, rising out of the use of or inability to use the sample script, 
    even if Microsoft has been advised of the possibility of such damages.
#>

<# 
//-----------------------------------------------------------------------
 
THE SUBJECT SCRIPT IS PROVIDED “AS IS” WITHOUT ANY WARRANTY OF ANY KIND AND SHOULD ONLY BE USED FOR TESTING OR DEMO PURPOSES.
YOU ARE FREE TO REUSE AND/OR MODIFY THE CODE TO FIT YOUR NEEDS
 
//-----------------------------------------------------------------------
#>

### Testing if required modules can be imported
try {
    Write-Host "===============================" -ForegroundColor Green
    Write-Host " Imported Az.Accounts Moduele !" -ForegroundColor Green
    Write-Host "===============================" -ForegroundColor Green
    import-Module Az.Accounts -force
}
catch {
    Write-Host "Failed to import the Az.Accounts module. Error details: $($_.Exception.Message)" -ForegroundColor Red
    exit
}
try {
    Write-Host "==================================" -ForegroundColor Green
    Write-Host " Imported Az.ResourceGraph Module!" -ForegroundColor Green
    Write-Host "==================================" -ForegroundColor Green
    import-Module Az.ResourceGraph -force
}
catch {
    Write-Host "Failed to import the Az.ResourceGraph module. Error details: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

### Connecting to Azure
try {
    # Prompt the user to connect to Azure
    Connect-AzAccount -ErrorAction Stop

    Write-Host "================================" -ForegroundColor Green
    Write-Host "Connected to Azure successfully!" -ForegroundColor Green
    Write-Host "================================" -ForegroundColor Green

    # If the script reaches this point, the user has successfully connected.
    # You can add more logic or commands here based on the successful connection.
}
catch {
    # Handle the error and provide more information to the user
    Write-Host "Failed to connect to Azure. Error details: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

### Importing AppInsights Configuration using KQL and Resource Graph
$WebAppList = Search-AzGraph -Query "resources | where type =~ 'microsoft.web/sites'" -UseTenantScope -first 1000
$WebAppList = $WebAppList | Sort-Object -Property subscriptionId
$FixRequired = @()

### Testing AppInsights
foreach ($webapp in $WebAppList)
{
    $WebAppInsight = $null

    $TempSub = get-azcontext | select-object Subscription | out-null
    if ($WebApp.subscriptionId -ne $TempSub.subscription.id)
    {
        set-AzContext -Subscription $WebApp.SubscriptionId | out-null
    }

    $resourceGroupName = $webapp.resourceGroup
    $webAppName = $webapp.name
    $WebAppInsight = Get-AzWebApp -ResourceGroupName $resourceGroupName -Name $webAppName
    $SiteConf = (($WebAppInsight).Siteconfig.appsettings).value

    if ($SiteConf)
    {
        foreach ($VariableConf in $SiteConf)
        {
            if ($VariableConf -like "*InstrumentationKey*" -and $VariableConf -notlike "*http*")
            {
                $FixRequired += $WebAppInsight | select-object name,resourceGroup,location,Tags,@{Name="ConnectionString"; Expression={($WebAppInsight | Select-Object -ExpandProperty Siteconfig | Select-Object -ExpandProperty appsettings | where name -like "*CONNECTION*").value}},id
            }
        }
    }
}

### Exporting Log to CSV
if ($FixRequired.Count -eq 0)
{
    Write-Host "No AppInsight ConnectionString found" -ForegroundColor Green
} else {
    # Mapping export path
    Write-Host "=====================================================" -ForegroundColor Yellow
    Write-Host "Default Export Path: C:\temp (Type Enter for default)" -ForegroundColor Yellow
    Write-Host "=====================================================" -ForegroundColor Yellow
    $CSVPath = Read-Host "Enter the path for the CSV File" -erroraction 'silentlycontinue'
    if (-not $CSVPath)
    {
        $CSVPath = "c:\temp"
        if (!(Test-Path $CSVPath))
        {
            New-Item -ItemType Directory -Path $CSVPath
        }
    }

    # Printing results
    Write-Host "=========================" -ForegroundColor Green
    Write-Host "Pringing log information:" 
    Write-Host "=========================" -ForegroundColor Green
    $FixRequired | ft
    #exporting results to CSV:
    $FixRequired | Export-Csv "$($CSVPath)\$((Get-Date).ToString("yyyyMMdd_HHmmss"))_AppInsight_Insights_ConnectionString.csv" -NoTypeInformation
}
