# Check the status of IP's provided in iplist.txt

$ips = Get-content "iplist.txt"

foreach ($ip in $ips){
  if (Test-Connection $ip -Count 1 -ErrorAction SilentlyContinue){
    Write-Host "$ip,Online"
  }
  else{
    Write-Host "$ip,Offline"
  }
}
