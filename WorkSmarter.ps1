function Show-Menu
{
     param (
           [string]$Title = 'Work Smarter'
     )
     cls
     Write-Host "================ $Title ================"
    
     Write-Host "1: Press '1' to create an Update Report"
     Write-Host "2: Press '2' to check for DFSRBacklog"
     Write-Host "3: Press '3' to change the RDP Port"
     Write-Host "4: Press '4' to check Check domain NTP settings (Run from DC)"
     Write-Host "5: Press '5' to check McAfee version"
     Write-Host "6: Press '6' to check Reboot Logs"
     Write-Host "7: Press '7' to check for Manual Failovers"
     Write-Host "Q: Press 'Q' to quit."
}

do
{
     Show-Menu
     $input = Read-Host "Please make a selection"
     switch ($input)
     {
           '1' {
                cls
                Function Get-UpdateReport { 
       
    [CmdletBinding( 
        DefaultParameterSetName = 'computer' 
        )] 
    param( 
        [Parameter(ValueFromPipeline = $True)] 
            [string[]]$ComputerName = $env:COMPUTERNAME
        )     
        $host.PrivateData.WarningForegroundColor = 'Red'
        $output = ForEach ($Computer in $Computername) { 
            If (Test-Connection -ComputerName $Computer -Count 1 -Quiet) { 
                Try { 
                #Create Session COM object 
                    Write-Verbose "Creating COM object for $Computer" 
                    $updatesession =  [activator]::CreateInstance([type]::GetTypeFromProgID("Microsoft.Update.Session",$computer)) 
                    } 
                Catch { 
                    Write-Warning "$($Error[0])" 
                    Continue 
                    } 
 
                #Configure Object 
                $updatesearcher = $updatesession.CreateUpdateSearcher() 
 
                #Get last installed update details
                $LastInstall = $updatesearcher.QueryHistory(0, 5) | Select-Object Date, 
                @{
                    name="Operation"; expression={switch($_.operation)
                        {
                            1 {"Installation"}
                            2 {"Uninstallation"}
                            3 {"Other"}
                        }
                    }
                },
                @{
                    name="Status"; expression={switch($_.resultcode)
                        {
                            1 {"In Progress"}
                            2 {"Succeeded"}
                            3 {"Succeeded With Errors"} 
                            4 {"Failed"}
                            5 {"Aborted"} 
                        }
                    }
                }, Title

                    Write-Output "<h2> Latest Update history for $computer</h2>"
                               $LastInstall | ConvertTo-Html -Fragment
                
                    
                                #Search for updates that are not installed
                    Write-Verbose "Searching for updates on $Computer" 
                                    $searchresult = $updatesearcher.Search("IsInstalled=0")     
             
                                #Verify if updates are pending 
                                If ($searchresult.Updates.Count -gt 0) { 
                    Write-Verbose "$($searchresult.Updates.Count) updates available!" 
                    Write-Output "<h2> Pending Updates for $computer</h2>"
                                #Cache the count to make the For loop run faster 
                                $count = $searchresult.Updates.Count 


                                #Iterate through available updates 
                                $Pending = For ($i=0; $i -lt $Count; $i++) { 
                                #Create object holding update 
                                $Update = $searchresult.Updates.Item($i)
                                [pscustomobject] @{
                                #ComputerName = $Computer
                                Title = $Update.Title
                                KB = $($Update.KBArticleIDs)
                                IsDownloaded = $Update.IsDownloaded
                                Url = $($Update.MoreInfoUrls)   
                            } 
                    }
                                $Pending | ConvertTo-Html -Fragment
                } 
                            Else { 
                            #Nothing to install at this time 
                    Write-Verbose "No updates to install." 
                }
                            } # end if test-connection statement
                            Else { 
                            #No response from computer 
                    Write-Warning "Cannot detect updates for $computer." 
            }  
                            } # end foreach 
							
                    Write-Verbose "Saving report to $env:USERPROFILE\Desktop\WinUpdates.html"    
                    ConvertTo-Html -head $head -PostContent $output -Title "Windows Updates" -PreContent "<h1> Windows Update Report </h1>" | Out-file $env:USERPROFILE\Desktop\WinUpdates.html

                            } # end function block

                            try {
                    Import-Module ActiveDirectory -ErrorAction 0
                            $ComputerName=Get-ADComputer -Filter {enabled -eq $true} -properties *| 
                            Where-Object name -notlike "*CLSTR*"| 
                            Select-Object -ExpandProperty Name
} 
                            Catch {
                    Write-Warning "Cannot load ActiveDirectory Module. Running against Local Machine?"
                            $ComputerName = $env:COMPUTERNAME
}

                    Get-UpdateReport -ComputerName $ComputerName -Verbose

           } '2' {
                cls
                    $Source = Read-Host -Prompt 'Input the SOURCE server name'
                    $Destination = Read-Host -Prompt 'Input the DESTINATION server name'
                    $RGName= Read-Host -Prompt 'Input the Replication Group name'
                    $RFName = Read-Host -Prompt 'Input the Replicated Folder name'
                    Write-Host "Checking for DFSR Backlog between '$Source' and '$Destination'" 

                    dfsrdiag backlog /rgname:$RGName /rfname:$RFName /sendingmember:$Source /receivingmember:$Destination

                    dfsrdiag backlog /rgname:$RGName /rfname:$RFName /sendingmember:$Destination /receivingmember:$Source

                    Write-Host "Press any key to exit."
                    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

           } '3' {
                cls
                        $RDPPort= Read-Host -Prompt 'What port number should be used? Please reboot on completion'
                        Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\Terminal*Server\WinStations\RDP-TCP\ -Name PortNumber -Value $RDPPort
           } '4' {
                cls
                        $computername=Get-ADComputer -Filter {enabled -eq $true} -properties *|? operatingsystem -like "*server*" |? name -notlike "*CLSTR*"|select -Expand Name
                        $timesource=w32tm /query /computer:$Server /source 

                        foreach ($server in $computername) {
                        Write-output "$server gets time from $timesource"
}

           } '5' {
                cls
                        function getmcafee{
                            $cma = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |  Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Where-Object {$_.DisplayName -like "McAfee*"}
                        if ($null -ne $cma) {
                            $cma = $cma | where-object displayname -like "McAfee Agent" | select displayname, DisplayVersion
                            $dn = $cma.displayname
                            $dv = $cma.DisplayVersion
                            $Global:softwareinfo += @{
                            McAfee = "$dn $dv GREEN"
                        }
                        }
                        else {
                            $Global:softwareinfo += @{
                            McAfee = "Not Installed WARNING"
        }
    }
}
            } '6' {
                cls
                        Get-EventLog -Logname System -Newest 5 -Source "USER32" | Select TimeGenerated,Message -ExpandProperty Message
                return
            } '7' {
                cls
                        Get-WinEvent  Microsoft-Windows-FailoverClustering/Diagnostic | ? {$_.Timecreated -gt [datetime]::Now.AddHours(-24) -and $_.Message -like "*MoveType:MoveType::Manual*"} | fl TimeCreated,Message
                   }
        }
pause
}
until ($input -eq 'q')

