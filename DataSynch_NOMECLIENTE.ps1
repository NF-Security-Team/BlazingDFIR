###############################################################
# Name: DataSynch.ps1
# Description: Uploads logs & Mal_Data to IR infrastructure
# Credits: Yarix_IR TEAM - "ir@yarix.com"
# ** When in the presence of a wise man,  ask him what you do not know;  when in the presence of a fool ask him what you do know.
###############################################################
#ARGS

$username=$args[0]
$password=$args[1]

	

$_localFilePath = -join("C:\", $env:computername, ".zip");
Write-Host "USERNAME --> " $username;
Write-Host "PASSWORD --> " $password;
Write-Host "$_localFilePath --> "$_localFilePath;
$filepath = Get-ChildItem $_localFilePath;

$newFileName = -join("ftp://download.yarix.com/", $filepath.BaseName, ".zip");
$request = [Net.WebRequest]::Create($newFileName);
$request.Credentials = New-Object System.Net.NetworkCredential($username, $password);
$request.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile;

$fileStream = [System.IO.File]::OpenRead($_localFilePath);
$ftpStream = $request.GetRequestStream();

$fileStream.CopyTo($ftpStream);

$ftpStream.Dispose();
$fileStream.Dispose();	

# 0) Executes Velociraptor(run.bat) & BlazingDFIR.ps1
# 1) Find the zippedFile "%HOSTNAME%_DFIR.zip" in the Whole filesystem
# 2) Get into Variable
# 3) Upload file into "download.yarix.com/IRDemo"
# 4) Checks if the upload has been done correctly