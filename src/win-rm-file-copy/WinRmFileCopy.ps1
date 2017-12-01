[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

try
{
    # Get inputs for the task
    [string]$machineNames = Get-VstsInput -Name MachineNames -Require
    [string]$adminUserName = Get-VstsInput -Name AdminUserName -Require
    [string]$adminPassword = Get-VstsInput -Name AdminPassword -Require
    [string]$sourcePath = Get-VstsInput -Name SourcePath -Require
    [string]$targetPath = Get-VstsInput -Name TargetPath -Require
    [bool]$cleanTargetBeforeCopy = Get-VstsInput -Name CleanTargetBeforeCopy -AsBool
    [bool]$copyFilesInParallel = Get-VstsInput -Name CopyFilesInParallel -AsBool
    [bool]$verbose = Get-VstsTaskVariable -Name "System.Debug" -AsBool

    $sourcePath = $sourcePath.Trim('"')
    $targetPath = $targetPath.Trim('"')

    # Normalize admin username
    if($adminUserName -and (-not $adminUserName.StartsWith(".\")) -and ($adminUserName.IndexOf("\") -eq -1) -and ($adminUserName.IndexOf("@") -eq -1))
    {
        $adminUserName = ".\" + $adminUserName 
    }

    if(-not (Test-Path -LiteralPath $sourcePath))
    {
        throw "Source path '$sourcePath' does not exist."
    }
    else
    {
        $path = Get-Item $sourcePath
        
        if ($path -is [System.IO.DirectoryInfo] -and (-not ($sourcePath.EndsWith("\"))))
        {
            $sourcePath += "\*"
        }
    }

    if (-not ([System.IO.Path]::IsPathRooted($targetPath)))
    {
        throw "Target path needs to contain root folder as 'C:\'"
    }

    if (-not ($targetPath.EndsWith("\")))
    {
        $targetPath += "\"
    }

    Write-Output "Files from '$sourcePath' will be copied to the path '$targetPath' on the remote machine(s)."

    $machines = $machineNames.split(',') | ForEach-Object { if ($_ -and $_.trim()) { $_.trim() } }

    $secureAdminPassword = ConvertTo-SecureString $adminPassword -AsPlainText -Force
    $machineCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminUserName, $secureAdminPassword

    if ($machines.Count -eq 0)
    {
        throw "No machine exists under environment: '$machineNames' for deployment"
    }

    $copyJob = {
        param
        (
            [string]$fqdn, 
            [string]$sourcePath,
            [string]$targetPath,
            [System.Management.Automation.PSCredential]$credential,
            [bool]$cleanTargetBeforeCopy,
            [bool]$verbose
        )

        try
        {
            $session = New-PSSession -ComputerName $fqdn -Credential $credential

            $testPath = {
                param ([string]$targetPath)
        
                if (-not (Test-Path -LiteralPath $targetPath -IsValid -PathType Container))
                {
                    throw "Destination path is not a valid path."
                }
        
                if (-not (Test-Path -LiteralPath $targetPath -PathType Container))
                {
                    New-Item -ItemType Directory -Force -Path $targetPath | Out-Null
                    Write-Verbose "Created destination folder '$targetPath'."
                }
            }

            Invoke-Command -Session $session -ScriptBlock $testPath -ArgumentList $targetPath

            if ($cleanTargetBeforeCopy)
            {
                Invoke-Command -Session $session -ScriptBlock { param ([string]$path) Get-ChildItem $path -Force | Remove-Item -Recurse -Force } -ArgumentList $targetPath
            }

            Copy-Item -Path $sourcePath -Destination $targetPath -Force -Recurse -Container -ToSession $session -Verbose:$verbose
        }
        finally
        {
            Write-Verbose "Closing Powershell remote session on $fqdn.";
            if ($session -ne $null) { $session | Disconnect-PSSession | Remove-PSSession }
        }
    }

    if ($copyFilesInParallel -eq $false -or ($machines.Count -eq 1))
    {
        foreach($machine in $machines)
        {
            Write-Output "Copy started for -  $machine"

            Invoke-Command -ScriptBlock $CopyJob -ArgumentList $machine, $sourcePath, $targetPath, $machineCredential, $cleanTargetBeforeCopy, $verbose
        } 
    }
    else
    {
        [hashtable]$Jobs = @{} 

        foreach($machine in $machines)
        {
            Write-Output "Copy started for -  $machine"

            $job = Start-Job -ScriptBlock $CopyJob -ArgumentList $machine, $sourcePath, $targetPath, $machineCredential, $cleanTargetBeforeCopy, $verbose

            $Jobs.Add($job.Id, $machine)
        }        

        While ($Jobs.Count -gt 0)
        {
            Start-Sleep 3 
            foreach($job in Get-Job)
            {
                if($Jobs.ContainsKey($job.Id) -and $job.State -ne "Running")
                {
                    Receive-Job -Id $job.Id
                    Remove-Job $Job                 
                    $Jobs.Remove($job.Id)
                } 
            }
        }
    }

    Write-Output "Copy succeeded."
}
catch
{
    Write-Verbose $_.Exception.ToString() -Verbose
    throw
}
finally
{
    Trace-VstsLeavingInvocation $MyInvocation
}