$username=$args[0]
$password=$args[1]

while($true)
{
$hostname = hostname;
$UploadFile = -join("put ", $hostname, ".zip");
$sessionOpen = -join("open ftp://" , $username, ":", $password, "@download.yarix.com/");
& ".\tools\WinSCP.com" `
  /log=".\WinSCP.log" /ini=nul `
  /command `
	$sessionOpen `
	"lcd C:\" `
	"cd /" `
	$UploadFile `
	"exit"

$winscpResult = $LastExitCode
if ($winscpResult -eq 0)
{
  Write-Host "Success"
  break;
  exit $winscpResult
}
else
{
  Write-Host "Error... retying in 30 seconds...";
  Sleep(30);
}


}
