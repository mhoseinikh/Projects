/*
EXECUTE GENSCRIPT.USP_MAKE_POWERSHELL_SCRIPT

*/

USE PostBankCounter_Source;
GO

CREATE OR ALTER PROCEDURE GENSCRIPT.USP_MAKE_POWERSHELL_SCRIPT
AS
BEGIN
    DECLARE @ServerName SYSNAME;
    DECLARE @Query VARCHAR(4000);
    DECLARE @Queryout VARCHAR(500);
    DECLARE @User VARCHAR(200);
    DECLARE @Pass VARCHAR(200);
    DECLARE @Command VARCHAR(8000);

    SET @Query='
param( 
    [string]$ServerName, 
    [string]$UserName, 
    [string]$Password, 
    [string]$DatabaseName, 
    [string]$SchemaName, 
    [string]$ObjectName, 
    [string]$ObjectType
) 
 
# Load SMO 
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null 
 
# Connect to SQL Server 
$server = New-Object Microsoft.SqlServer.Management.Smo.Server $ServerName 
$server.ConnectionContext.LoginSecure = $false 
$server.ConnectionContext.set_Login($UserName) 
$server.ConnectionContext.set_SecurePassword((ConvertTo-SecureString $Password -AsPlainText -Force)) 
$database = $server.Databases[$DatabaseName] 
 
# Select Object 
switch ($ObjectType.ToLower()) 
{ 
    "procedure" { $smoObject = $database.StoredProcedures["$ObjectName", "$SchemaName"] } 
    "table" { $smoObject = $database.Tables[$ObjectName, $SchemaName] } 
    "view" { $smoObject = $database.Views["$ObjectName", "$SchemaName"] } 
    "function" { $smoObject = $database.UserDefinedFunctions["$ObjectName", "$SchemaName"] } 
    default { Write-Host "Unsupported object type"; exit } 
} 
 
# Generate script 
$scripter = New-Object Microsoft.SqlServer.Management.Smo.Scripter $server 
$scripter.Options.ScriptSchema = $true 
$scripter.Options.ScriptData = $false
$scripter.Options.IncludeIfNotExists = $true 
$scripter.Options.DriAll = $true 
$scripter.Options.Indexes = $true 
$scripter.Options.Triggers = $true 
$scripter.Options.Constraints = $true 
$scripter.Options.DriPrimaryKey = $true 
$scripter.Options.DriForeignKeys = $true 
$scripter.Options.DriUniqueKeys = $true 
$scripter.Options.DriDefaults = $true 
$scripter.Options.DriChecks = $true 
$scripter.Options.WithDependencies = $false 
$scripter.Options.ScriptUseDatabase = $false

$script = $scripter.Script($smoObject) -join "`r`n" 
if ($ObjectType.ToLower() -eq "view") {
    $dropScript = "DROP VIEW IF EXISTS [$SchemaName].[$ObjectName];"
    $script = $dropScript + "`r`n" + $script
}
if ($ObjectType.ToLower() -eq "function") {
    $dropScript = "DROP FUNCTION IF EXISTS [$SchemaName].[$ObjectName];"
    $script = $dropScript + "`r`n" + $script
}
if ($ObjectType.ToLower() -eq "procedure") {
    #$escapedSchema = [regex]::Escape($SchemaName)
    #$escapedObject = [regex]::Escape($ObjectName)
    #$pattern = "(?i)\bALTER\s+PROCEDURE\s+(\[?$escapedSchema\]?\.)\[?$escapedObject\]?"
    #$scriptModified = [regex]::Replace($scriptEscaped, $pattern, {
    #    param($match)
    #    return "IF 1=1`r`nBEGIN`r`nEXEC dbo.sp_executesql @statement = N''" + $match.Value
    #}, ''IgnoreCase'')
    #$script = $scriptModified.TrimEnd() + "''`r`nEND"

    $escapedSchema = [regex]::Escape($SchemaName)
    $escapedObject = [regex]::Escape($ObjectName)
    $pattern = "(?i)\bALTER\s+PROCEDURE\s+(\[?$escapedSchema\]?\.)\[?$escapedObject\]?"
    $match = [regex]::Match($script, $pattern, ''IgnoreCase'')
    $startIndex = $match.Index

    $before = $script.Substring(0, $startIndex)
    $after = $script.Substring($startIndex)

    $afterEscaped = $after -replace "''", "''''"

    $afterModified = [regex]::Replace($afterEscaped, $pattern, {
        param($m)
        return "IF 1=1`r`nBEGIN`r`nEXEC dbo.sp_executesql @statement = N''" + $m.Value
    }, ''IgnoreCase'')
    $script = $before + $afterModified.TrimEnd() + "''`r`nEND"
}

$escapedScript = $script.Replace("''", "''''") 
 
# Insert into SQL Server TABLE 
$query = "INSERT INTO TempDB..tmptable_USP_GENERATE_OBJECT_DDL (ScriptContent) VALUES (''$escapedScript'')" 
 
Invoke-Sqlcmd -ServerInstance $ServerName -Username $UserName -Password $Password -Database $DatabaseName -Query $query 
';
    DROP TABLE IF EXISTS tempdb.dbo.tmpText;
    CREATE TABLE tempdb.dbo.tmpText ([textline] NVARCHAR(MAX));
    INSERT INTO tempdb.dbo.tmpText 
        VALUES (@Query);

    SET @Query='SELECT textline FROM tempdb.dbo.tmpText;'
    SELECT  TOP 1 
            @User=s.set_ServerUserName,
            @Pass=s.set_ServerPassword,
            @Queryout=s.set_PowerShell
        FROM GENSCRIPT.SETTING s
    SELECT @ServerName=c.local_net_address
      FROM sys.dm_exec_connections c
      WHERE c.session_id = @@SPID;  
    SET @Command = 'bcp "'+@Query+'" queryout "'+@Queryout+'" -c -U '+@User+' -P '+@Pass+' -S ' + @ServerName;
 
    EXECUTE sp_configure 'show advanced options', '1'
    RECONFIGURE
    EXECUTE sp_configure 'xp_cmdshell', '1'
    RECONFIGURE 

    EXECUTE xp_cmdshell @Command, NO_OUTPUT;

    EXECUTE sp_configure 'show advanced options', '1'
    RECONFIGURE
    EXECUTE sp_configure 'xp_cmdshell', '0'
    RECONFIGURE 

END;
GO

