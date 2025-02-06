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

### Testing if required modules can be imported
try {
    import-Module Az.Websites -force
}
catch {
    Write-Host "Failed to import the Az.Websites module. Error details: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

### Importing WebApps Configuration using KQL and Resource Graph
$WebAppsList = Search-AzGraph -Query "resources | where type =~ 'Microsoft.Web/sites'" -UseTenantScope
$FixRequired = @()

### Testing WebApps
foreach ($WebApp in $WebAppsList)
{
    $TempSub = get-azcontext | select-object Subscription | out-null
    if ($WebApp.subscription -ne $TempSub.subscription.id)
    {
        set-AzContext -Subscription $Entry.Subscription | out-null
    }

    $resourceGroupName = $WebApp.resourceGroup
    $webAppName = $WebApp.name
    $WebAppInsight = ((Get-AzWebApp -ResourceGroupName $resourceGroupName -Name $webAppName).Siteconfig.appsettings | where name -eq  "APPLICATIONINSIGHTS_CONNECTION_STRING").value

    if ($WebAppInsight -notlike "*=*")
    {
        $FixRequired += $WebApp
    }

}

### Exporting Log to CSV
# Mapping export path
Write-Host "=====================================================" -ForegroundColor Yellow
Write-Host "Default Export Path: C:\temp (Type Enter for default)" -ForegroundColor Yellow
Write-Host "=====================================================" -ForegroundColor Yellow
$CSVPath = Read-Host "Enter the path for the CSV File" -erroraction 'silentlycontinue'
if (-not $CSVFile)
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
$LOG | ft
#exporting results to CSV:
$LOG | Export-Csv "$($CSVPath)\$((Get-Date).ToString("yyyyMMdd_HHmmss"))_WebApp_Insights_ConnectionString.csv" -NoTypeInformation
