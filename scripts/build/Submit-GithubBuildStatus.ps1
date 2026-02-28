<#
.SYNOPSIS
    Submits a CI build status to GitHub for the latest SHA1 in a pull request branch.
#>
[CmdletBinding(SupportsShouldProcess=$True)]
Param (
	[Parameter(Mandatory=$true, HelpMessage="GitHub Pull Request specifier (<origin> <branch>)")]
	[string]$PullRequest,

	[Parameter(Mandatory=$true, HelpMessage="Parent repository (<USER/REPO>)")]
	[string]$Repository,

	[Parameter(Mandatory=$true, HelpMessage="Build Definition Name")]
	[string]$BuildDefinition,

	[Parameter(Mandatory=$true,ParameterSetName="ManualStatus", HelpMessage="Manually-specified status")]
	[ValidateSet('pending', 'success', 'failure')]
	[string]$Status,

	[Parameter(Mandatory=$true,ParameterSetName="AutomaticStatus", HelpMessage="Test output directory for automatic status")]
	[string]$TestXMLDirectory,

	[Parameter(Mandatory=$true, HelpMessage="GitHub username with repo:status scope")]
	[string]$AuthUsername,

	[Parameter(Mandatory=$true, HelpMessage="GitHub Authentication token")]
	[string]$AuthToken,

	[Parameter(HelpMessage="Optional description prepended to test results")]
	[string]$Description,

	[Parameter(HelpMessage="Optional status-related URL")]
	[string]$DetailsURL
)

$ErrorActionPreference = "Stop";

Function Get-LatestRevision {
	$ret = (& git.exe ls-remote ($PullRequest -Split " "))
	If ($LASTEXITCODE -NE 0) {
		Throw "Failed to find latest SHA1 for $PullRequest."
	}
	return $ret.Split("`t")[0]
}

If ($PsCmdlet.ParameterSetName -Eq "AutomaticStatus") {
	$testCount = 0
	$failureCount = 0
	$disabledCount = 0
	ForEach($xmlItem in (Get-ChildItem $TestXMLDirectory -ErrorAction SilentlyContinue -Recurse -File)) {
		[xml]$xml = Get-Content $xmlItem.FullName
		$testCount += $xml.'WTT-Logger'.PFRollup.Total
		$failureCount += $xml.'WTT-Logger'.PFRollup.Failed
		$disabledCount += $xml.'WTT-Logger'.PFRollup.Blocked
	}

	If ($testCount -Eq 0) {
		$Status = "failure"
		$explanation = "Build failed (no tests run)"
	} ElseIf ($failureCount -Gt 0) {
		$Status = "failure"
		$explanation = "{0}/{1} test{2} failed" -f $failureCount, $testCount, $(If ($testCount -Ne 1) { "s" })
	} Else {
		$Status = "success"
		$explanation = "{0}/{0} test{1} passed" -f $testCount, $(If ($testCount -Ne 1) { "s" })
	}

	# If no tests run, disabledCount will be 0 anyway.
	If ($disabledCount -Gt 0) {
		$explanation += ", {0} disabled test{1} skipped" -f $disabledCount, $(If ($disabledCount -Ne 1) { "s" })
	}

	If (![string]::IsNullOrWhiteSpace($Description)) {
		$Description += "; ";
	}
	$Description += $explanation
}

$latestSha1 = Get-LatestRevision

$statusURL = "https://api.github.com/repos/$($Repository)/statuses/$($latestSha1)"
$newStatus = [PSCustomObject]@{
	state = $Status;
	context = $BuildDefinition;
	description = $(If ([string]::IsNullOrWhiteSpace($Description)) { "" } Else { $Description });
	target_url = $(If ([string]::IsNullOrWhiteSpace($DetailsURL)) { "" } Else { $DetailsURL });
}

# Bug; GitHub sends a 404 for authentication failures. Unfortunately, Invoke-WebRequest waits for a 401 before retrying with
# an authentication header. Therefore, we have to build the auth header ourselves.
# The correct version of this code is:
#     $authTokenSecureString = (ConvertTo-SecureString -String $AuthToken -AsPlainText -Force)
#     $authCredential = (New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $AuthUsername, $authTokenSecureString)
$encodedAuthCredential = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($AuthUsername):$($AuthToken)"))
$statusHeaders = @{
	Authorization = "Basic $($encodedAuthCredential)"
}

If ($PSCmdlet.ShouldProcess($latestSha1, "GitHub Build Status")) {
	Try {
		Add-Type -Assembly System.Net
		[System.Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
	} Catch {
		Write-Warning "Failed to set TLS level: $_"
	}

	Invoke-WebRequest -Body (ConvertTo-JSON $newStatus) -ContentType "application/json" -Headers $statusHeaders -Method Post -Uri $statusURL | Out-Null
} Else {
	Write-Host "Would submit build status:"
	Write-Host $newStatus
}
