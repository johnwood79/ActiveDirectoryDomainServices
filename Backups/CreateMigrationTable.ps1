<#
  This script will generate a migration table from all GPOs found in the domain
  that can be used to perform GPO migration between domains 

  Syntax examples:
    Create:
      CreateMigrationTable.ps1 -Action Create -MigrationTable AllGPO.migtable
    Modify:
      CreateMigrationTable.ps1 -Action Modify -MigrationTable AllGPO.migtable

  It is based on the following two scripts:
    1) The CreateMigrationTable.wsf Group Policy Sample Script from Microsoft.
    2) Using Powershell to generate Group Policies migration table by Griffon:
       http://c-nergy.be/blog/?p=3067

  References and links : http://msdn.microsoft.com/en-us/library/windows/desktop/aa814302(v=vs.85).aspx

  Release 1.1
  Written by Jeremy@jhouseconsulting.com 11th September 2013
  Modified by Jeremy@jhouseconsulting.com 28th January 2014

#>

#-------------------------------------------------------------
param([String]$Action,[String]$MigrationTable)

# Get the script path
$ScriptPath = {Split-Path $MyInvocation.ScriptName}

if ([String]::IsNullOrEmpty($Action))
{
    write-host -ForeGroundColor Red "Action is a required parameter. Exiting Script.`n"
    exit
} else {
  switch ($Action)
  {
    "Create" {$Create = $true;$Modify = $false}
    "Modify" {$Create = $false;$Modify = $true}
    default {$Create = $false;$Modify = $false}
  }
}
if ([String]::IsNullOrEmpty($MigrationTable))
{
    write-host -ForeGroundColor Red "MigrationTable is a required parameter. Exiting Script.`n"
    exit
} else {
  $migtablePath = $(&$ScriptPath) + "\$MigrationTable"
}

#-------------------------------------------------------------
If ($Create -eq $true) {

  ## Get the domain name automatically 
  $domain=[System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().name

  ## Load the Com Object
  $gpm = new-object -comobject gpmGMT.gpm
  $constants = $gpm.getConstants()

  ## Connect to domain and get a list of the GPOs
  $gpmDomain = $gpm.GetDomain($domain,$null,$constants.useanydc)
  $gpmSearchCriteria = $gpm.CreateSearchCriteria()
  $gpoList = $gpmDomain.SearchGpos($gpmSearchCriteria)
  write-host -ForeGroundColor Green "Searching" $gpoList.Count "GPOs..."

  ## Create the migration Table
  $migtable=$gpm.createMigrationTable()

  ## Loop through each gop and retrieve values (user,computer,unc,...) 
  foreach($gpo in $gpoList) {
    write-host -ForeGroundColor Green " - " $gpo.Displayname
    $Right=$constants.ProcessSecurity
    $MigTable.Add($Right,$GPO)
  }

  ## Save the migration table to the specified location 
  $migTable.save($migtablePath)

}

#-------------------------------------------------------------
If ($Modify -eq $true) {

  ## MODIFY THE MIGRATION TABLE FILE
  ## We need to include NetBIOS Domain name and DNS Domain Name replacement mechanisms

  $CurrentDomain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
  $CurrentDNSDomainName = $CurrentDomain.Name
  $CurrentNetBIOSDomainName = $CurrentDomain.Name.Split(".")[0].ToUpper()

  $PlaceHolderDNSDomainName = "migrationtable.local"
  $PlaceHolderNetBIOSDomainName = "migrationtable"

  if ((Test-Path $migtablePath) -eq $True) {

    [xml]$MTData = Get-Content $migtablePath

    foreach ($entity in $MTData.MigrationTable.Mapping) {

      $test = $entity.source

      ## DNS Domain Name
      if ($entity.source -like "*$CurrentDNSDomainName") {
        $entity.source = $entity.source -replace "$CurrentDNSDomainName","$PlaceHolderDNSDomainName"
        $entity.source
        $MTData.save($migtablePath)
      }

      ## NetBIOS Domain Name
      if ($entity.source -like "$CurrentNetBIOSDomainName\*") {
        $entity.source = $entity.source -replace "$CurrentNetBIOSDomainName\\","$PlaceHolderNetBIOSDomainName\"
        $entity.source
        $MTData.save($migtablePath)
      }
    }
  } else {
    Write-Host -ForegroundColor Red "The $migtablePath file is missing. Cannot modify the Migration Table.`n"
  }
}
