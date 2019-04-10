#Import activedirectory modules
if ($null -eq (Get-Module activedirectory))
{
    Import-Module activedirectory
}

if ($null -eq (Test-Path .\configData.xml))
{
    Write-Host "Please configData.xml file in the current directory." 
    Break    
}

$config = Import-Clixml .\configData.xml

$dateStr = (get-date).ToString("yyyyMMdd HH:mm:ss")

#Security Groups to Monitor Variables
$SecurityGroups = $config.securityGroups

#Path variables:
$path = $config.Path
if ((test-path $path ) -eq $FALSE)
{
    mkdir $path.ToString()
}


#Query active directory
foreach ($securitygroup in $SecurityGroups)
{
    $newfile = "$path\new-ADMonitor_$securitygroup.txt"
    $oldfile = "$path\old-ADmonitor_$securitygroup.txt"
    $nestedSecGroups = Get-ADGroupMember  $securitygroup | `
        Where-Object {$_.objectClass -eq "group"}
    
    #new run
    Get-ADGroupMember  $securitygroup | `
        Where-Object {$_.objectClass -eq "user"} | `
        Select-Object -ExpandProperty name | `
        Add-Content -Path $newfile
    if ($null -ne $nestedSecGroups)
    {
        foreach ($nestedSecGroup in $nestedSecGroups)
        {
            Get-ADGroupMember $securitygroup | `
                Select-Object -ExpandProperty name | `
                Add-Content -Path $newfile
        }
    }

    #Compare actions
    if ((test-path $oldfile) -eq $FALSE)
    {
        Move-Item $newfile $oldfile
        
    }
    else
    {
        $comp = compare-object (Get-Content $newfile) (Get-Content $oldfile)
        $groupschanged = $comp | `
            Select-Object -ExpandProperty InputObject
        if ($null -eq $comp)
        {
            out-null
        }
        elseif ($comp.SideIndicator -eq "<=")
        {   
            $dateStr + " - User's added to security group - " + $securitygroup + " - " + $groupschanged | `
                Add-Content $path\ADMonitor_LogFile.txt
            $message = "User added to " + $securitygroup + ":`n" + ( $comp.InputObject | % { "$_`n" } )  
            Send-MailMessage -From $config.Sender `
                -to $config.Recipient `
                -subject "User added to $securitygroup" `
                -body $message `
                -SmtpServer $config.SMTPRelay
        }
        elseif ($comp.SideIndicator -eq "=>")
        {
            $dateStr + " - User's removed from security group - " + $securitygroup + " - " + $groupschanged | `
                Add-Content $path\ADMonitor_LogFile.txt
            $message = "User removed from " + $securitygroup + ":`n" + ( $comp.InputObject | % { "$_`n" } )  
            Send-MailMessage -From $config.Sender `
                -to $config.Recipient `
                -subject "User removed from $securitygroup" `
                -body $message `
                -SmtpServer $config.SMTPRelay
        }
        else
        {
            "existencial crisis"
        }
        
    }
    move-item $newfile $oldfile -Force -ErrorAction SilentlyContinue

}

$dateStr + " - script successfully ran." | `
    Add-Content $path\ADMonitor_LogFile.txt