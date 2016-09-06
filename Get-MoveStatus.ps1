<#

.SYNOPSIS
This script will get the move status for all mailbox moves that have not completed yet.

.DESCRIPTION
This script will get the move status for all mailbox moves that have not completed yet.

The script refreshes the view of the mailboxes every 5 seconds by default.

It currently focuses on gathering migration data using Get-MoveRequest. Future versions may transition to Get-MigrationUser, especially if Microsoft moves away from exposing Move Request data.

The original verison of this script was created by Jason Sherry (izzy@izzy.org) | http://jasonsherry.org

.NOTES
    Version			: 1.0
    Wish list		: Better error handling
					  Change MB/min to GB/hr if possible - will probably require string manipulation and regex unfortunately.
					  Separate out parts of the script to make it more readable
					  Add parameters to allow the specification of the refresh time (currently set to 5 seconds by default)
					  Explore switching to the use of Get-MigrationUser
    Author(s)		: Michael Epping (mepping@concurrency.com)
    Assumptions		: ExecutionPolicy of AllSigned (recommended), RemoteSigned or Unrestricted (not recommended)
    Limitations		:
    Known Issues	: None yet, but I'm sure you'll find some!

.EXAMPLE
.\Get-MoveStatus.ps1

/#>

## Define Parameters


## Define Functions


## Start Script

	$Count = (Get-MoveRequest | ? {$_.Status -ne "Completed"} | measure-object).count
	While ($Count -gt 0) {
		Get-MoveRequest | ? {$_.Status -notLike "Completed*" -And $_.Status -ne "Queued" -And $_.Status -ne "AutoSuspended"} | Get-MoveRequestStatistics | Sort-Object Status,StartTimestamp | ft -wrap  @{label="User";expression={$_.DisplayName}}, @{label="%";expression={$_.PercentComplete}}, @{label="Status";expression={$_.Status}}, @{label="Start";expression={($_.StartTimestamp).ToString('MM/dd HH:mm')}}, @{label="Duration";expression={$_.TotalInProgressDuration}}, @{label="Items";expression={$_.TotalMailboxItemCount}}, @{label="Copied Data";expression={$_.BytesTransferred}}, @{label="MB/min";expression={$_.BytesTransferredPerMinute}}, <#@{label="Size";expression={$_.TotalMailboxSize}}, @{label="Bad Items";expression={$_.BadItemsEncountered}/#>}
		write-host "`t`t`nRefreshing in 5 seconds, hit CTRL-C to exit.`n" -Foregroundcolor "Yellow"
		start-sleep -s 5
		$Count = (Get-MoveRequest | ? {$_.Status -notLike "Completed*" -And $_.Status -ne "Queued"} | measure-object).count
	}
