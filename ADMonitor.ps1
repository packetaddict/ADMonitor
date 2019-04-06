#Import activedirectory modules
if ((Get-Module activedirectory) -eq $null)
{
    Import-Module activedirectory
}

#Security Groups to Monitor Variables
$SecurityGroups = @(
    "Domain Admins",
    "Enterprise Admins"
)

#Path variables:
$path = ".\ADMonitor"
if ((test-path $path ) -eq $FALSE)
{
    New-Item -ItemType Directory -name $path
}


#Query active directory
foreach ($securitygroup in $SecurityGroups)
{
    $newfile = "$path\new-ADMonitor_$securitygroup.txt"
    $oldfile = "$path\old-ADmonitor_$securitygroup.txt"
    $nestedSecGroups = Get-ADGroupMember  $securitygroup | `
    where {$_.objectClass -eq "group"}
    
    #new run
    Get-ADGroupMember  $securitygroup | `
    where {$_.objectClass -eq "user"} | `
    select -ExpandProperty name | `
    Add-Content -Path $newfile

    #Compare actions
    if ((test-path $oldfile) -eq $FALSE)
    {
        Move-Item $newfile $oldfile
        
    }
    else
    {
         
        $comp = compare-object (Get-Content $newfile) (Get-Content $oldfile)
        if ($comp -eq $null)
        {
            out-null
        }
        elseif ($comp.SideIndicator -eq "<=")
        {
            #$securitygroup
            "User's added to Security Group!" 
            $comp | select -ExpandProperty InputObject
        }
        elseif ($comp.SideIndicator -eq "=>")
        {
            #$securitygroup
            "User's removed from Security Group!"
            $comp | select -ExpandProperty InputObject
        }
        else
        {
            "existencial crisis"
        }
        
    }
    move-item $newfile $oldfile -Force
}
