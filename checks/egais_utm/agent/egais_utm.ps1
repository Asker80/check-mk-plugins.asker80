param(
    #$url = "http://m15-1c:8080" 
    $url = "http://$($env:COMPUTERNAME):8080"
)

function EscapeUnicode([string] $inStr)
{
    $builder = New-Object Text.StringBuilder
    for ($i = 0; $i -lt $inStr.Length; $i++)
    {
        if ([char]::IsSurrogatePair($inStr, $i))
        {
            $null = $builder.Append('\U' + [char]::ConvertToUtf32($inStr, $i).ToString("X8"));
            $i++;  #//skip the next char     
        }
        else
        {
            $charVal = [char]::ConvertToUtf32($inStr, $i);
            if ($charVal -gt 127)
            {
                $null = $builder.Append('\u' + $charVal.ToString("X4"));
            }
            else
            {
                #//an ASCII character 
                $null = $builder.Append($inStr[$i]);
            }
        }
    }
    return $builder.ToString();
}

$prevEAP = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

"<<<egais_utm>>>"

$env_var = [Environment]::ExpandEnvironmentVariables('%MK_PLUGINSDIR%')
$storageAssemblyPath = 'C:\Program Files (x86)\check_mk\HtmlAgilityPack.dll'
if ($env_var -ne '%MK_PLUGINSDIR%')
{
    $storageAssemblyPath = Join-Path (Split-Path $env_var) 'HtmlAgilityPack.dll'
}
try{
    $bytes = [System.IO.File]::ReadAllBytes($storageAssemblyPath)
    $null = [System.Reflection.Assembly]::Load($bytes)
    $bytes = $null
}catch {
    "egais transport_version CRIT Cannot load $storageAssemblyPath"
    $ErrorActionPreference = $prevEAP
    return
}
$web = New-Object HtmlAgilityPack.HtmlWeb

try{
    $wr = $web.Load($url)
}catch {
    "egais transport_version CRIT Cannot connect to server"
    $ErrorActionPreference = $prevEAP
    return
}

#$wr.StatusCode
#$wr.Headers
if ($web.StatusCode -eq 'OK')
{
    if ($wr.DocumentNode.SelectSingleNode("//head/title").ChildNodes['#text'].Text -ne "УТМ"){
        "egais transport_version CRIT HTML page is not Egais UTM"
        $ErrorActionPreference = $prevEAP
        return
    }
#    $pre_nodes = ((($wr.ParsedHtml.body.childNodes|?{$_.nodeName -eq "div" -and $_.className -contains "container"}).childNodes|
#        ?{$_.nodeName -eq "div" -and $_.className -eq "tab-content"}).childNodes|?{$_.nodeName -eq "div" -and $_.id -eq "home"}).childNodes|
#        ?{$_.nodeName -eq "pre"}

    $pre_nodes = $wr.DocumentNode.SelectNodes('//div[@class="container"]/div[@class="tab-content"]/div[@id="home"]/pre')
    $utm_ver = $pre_nodes[0].ChildNodes['#text'].Text.Split("`n")
    "egais transport_version OK $($utm_ver[0].Split(":")[1]) build $($utm_ver[2].Split(":")[1])"
    "egais transport_status $($pre_nodes[1].childNodes['img'].Attributes['alt'].Value) $(EscapeUnicode($pre_nodes[1].childNodes['#text'].Text.Replace('&nbsp;','').Trim()))"
    "egais license_status $($pre_nodes[2].childNodes['img'].Attributes['alt'].Value) $(EscapeUnicode($pre_nodes[2].childNodes['#text'].Text.Replace('&nbsp;','').Trim()))"
    "egais db_creation_date $($pre_nodes[3].childNodes['#text'].Text.Replace(' ','T').Trim())"
    if ($pre_nodes[4].childNodes['#text'].Text.Replace('&nbsp;','').Trim() -eq "Отсутствуют неотправленные розничные документы."){
        "egais unsent_docs OK"
    }
    else {
        $ar_split = $pre_nodes[4].childNodes['#text'].Text.Replace('&nbsp;','').Trim().Split(' ')
        "egais unsent_docs WARNING $($ar_split[0])T$($ar_split[1])$($ar_split[2])"
    }

    $ar_split = $pre_nodes[5].childNodes['#text'].Text.Replace('&nbsp;','').Split(' ')
    $cert_from = "$($ar_split[4])T$($ar_split[5])$($ar_split[6])"
    $cert_until = "$($ar_split[8])T$($ar_split[9])$($ar_split[10])"
    "egais cert_pki $($pre_nodes[5].childNodes['img'].Attributes['alt'].Value) $cert_from`t$cert_until"

    $ar_split = $pre_nodes[6].childNodes['#text'].Text.Replace('&nbsp;','').Split(' ')
    $cert_from = "$($ar_split[4])T$($ar_split[5])$($ar_split[6])"
    $cert_until = "$($ar_split[8])T$($ar_split[9])$($ar_split[10])"
    "egais cert_gost $($pre_nodes[6].childNodes['img'].Attributes['alt'].Value) $cert_from`t$cert_until"
}
else
{
    "egais transport_version WARNING HTTP error $($web.StatusCode)"
}
$ErrorActionPreference = $prevEAP

