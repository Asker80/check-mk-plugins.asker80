param(
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

$env_var = [Environment]::ExpandEnvironmentVariables('%MK_CONFDIR%')
$cfgFileName = 'C:\Program Files (x86)\check_mk\egais_utm.json'
if ($env_var -ne '%MK_CONFDIR%')
{
    $cfgFileName = Join-Path (Split-Path $env_var) 'egais_utm.json'
}
if (Test-Path $cfgFileName)
{
    $egais_utm_cfg = gc $cfgFileName | ConvertFrom-Json
    $url = "http://$($egais_utm_cfg.ComputerName):8080"
}

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

    # UTM version <= 2.0.5
    $status_nodes = $wr.DocumentNode.SelectNodes('//div[@class="container"]/div[@class="tab-content"]/div[@id="home"]/pre')
    if ($status_nodes -ne $null)
    {
        $utm_ver = $status_nodes[0].ChildNodes['#text'].Text.Split("`n")
        "egais transport_version OK $($utm_ver[0].Split(":")[1]) build $($utm_ver[2].Split(":")[1])"
        "egais transport_status $($status_nodes[1].childNodes['img'].Attributes['alt'].Value) $(EscapeUnicode($status_nodes[1].childNodes['#text'].Text.Replace('&nbsp;','').Trim()))"
        "egais license_status $($status_nodes[2].childNodes['img'].Attributes['alt'].Value) $(EscapeUnicode($status_nodes[2].childNodes['#text'].Text.Replace('&nbsp;','').Trim()))"
        "egais db_creation_date $($status_nodes[3].childNodes['#text'].Text.Replace(' ','T').Trim())"
        if ($status_nodes[4].childNodes['#text'].Text.Replace('&nbsp;','').Trim() -eq "Отсутствуют неотправленные розничные документы."){
            "egais unsent_docs OK"
        }
        else {
            $ar_split = $status_nodes[4].childNodes['#text'].Text.Replace('&nbsp;','').Trim().Split(' ')
            "egais unsent_docs WARNING $($ar_split[0])T$($ar_split[1])$($ar_split[2])"
        }
        $ar_split = $status_nodes[5].childNodes['#text'].Text.Replace('&nbsp;','').Split(' ')
        $cert_from = "$($ar_split[4])T$($ar_split[5])$($ar_split[6])"
        $cert_until = "$($ar_split[8])T$($ar_split[9])$($ar_split[10])"
        "egais cert_age PKI $($status_nodes[5].childNodes['img'].Attributes['alt'].Value) $cert_from`t$cert_until"
        $ar_split = $status_nodes[6].childNodes['#text'].Text.Replace('&nbsp;','').Split(' ')
        $cert_from = "$($ar_split[4])T$($ar_split[5])$($ar_split[6])"
        $cert_until = "$($ar_split[8])T$($ar_split[9])$($ar_split[10])"
        "egais cert_age GOST $($status_nodes[6].childNodes['img'].Attributes['alt'].Value) $cert_from`t$cert_until"
        $inc_doc_tbl = $wr.DocumentNode.SelectNodes('//div[@class="container"]/div[@class="tab-content"]/div[@id="menu5"]/table[@id="table-out"]')
#        $inc_doc_json = (Invoke-WebRequest "$url/$($inc_doc_tbl[0].Attributes['data-url'].Value)?order=asc&limit=1&offset=0" -UseBasicParsing).Content
#        $inc_doc_json_parsed = $inc_doc_json | ConvertFrom-Json
#        if ($inc_doc_json_parsed.total -eq 0)
#        {
#            "egais incoming_docs OK"
#        }
#        else
#        {
#            "egais incoming_docs WARNING $($inc_doc_json_parsed.rows[0].timestamp.Replace(' ','T'))"
#        }
        $status_nodes = $null
    }
    else
    {
        # UTM version >= 2.1.6
        $status_nodes = $wr.DocumentNode.SelectNodes('//div[@class="container"]/div[@class="tab-content"]/div[@id="home"]/div[@class="info-line row"]')
    }
    if ($status_nodes -ne $null)
    {
        $idx = 0
        $status_node = $status_nodes[$idx]
        "egais transport_version OK $($status_node.ChildNodes[1].ChildNodes['#text'].Text)"
        $idx += 1
        $status_node = $status_nodes[$idx]
        "egais transport_status $(if($status_node.ChildNodes[0].ChildNodes[0].Attributes['class'].Value.Contains('glyphicon-ok')){'OK'}else{'WARNING'}) $(EscapeUnicode($status_node.ChildNodes[0].ChildNodes['#text'].Text)): $(EscapeUnicode($status_node.ChildNodes[1].ChildNodes['#text'].Text))"
        if ($status_node.ChildNodes[0].ChildNodes['#text'].Text -eq 'Продуктивный контур') {
            $idx += 1
        }
        elseif ($status_node.ChildNodes[0].ChildNodes['#text'].Text -eq 'Проблемы с RSA') {
            $idx += 2
        }
        $status_node = $status_nodes[$idx]
        "egais license_status $(if($status_node.ChildNodes[0].ChildNodes[0].Attributes['class'].Value.Contains('glyphicon-ok')){'OK'}else{'WARNING'}) $(EscapeUnicode($status_node.ChildNodes[1].ChildNodes['#text'].Text))"
        $idx += 1
        $status_node = $status_nodes[$idx]
        "egais db_creation_date $($status_node.ChildNodes[1].ChildNodes['#text'].Text.Replace(' ','T'))"
        $idx += 1
        $status_node = $status_nodes[$idx]
        if ($status_node.ChildNodes[1].childNodes['#text'].Text -eq "Отсутствуют неотправленные чеки"){
            "egais unsent_docs OK"
        }
        else {
            $match_dates = [regex]::Matches($status_node.ChildNodes[1].ChildNodes['#text'].Text, '\d{4}-\d{2}-\d{2}')
            $match_times = [regex]::Matches($status_node.ChildNodes[1].ChildNodes['#text'].Text, '\d{2}:\d{2}:\d{2}\.\d{3}')
            $match_offsets = [regex]::Matches($status_node.ChildNodes[1].ChildNodes['#text'].Text, '\+\d{4}')
            "egais unsent_docs WARNING $($match_dates[0].Value)T$($match_times[0].Value)$($match_offsets[0].Value)"
        }
        $idx += 1
        $status_node = $status_nodes[$idx]
        $match_dates = [regex]::Matches($status_node.ChildNodes[1].ChildNodes['#text'].Text, '\d{4}-\d{2}-\d{2}')
        $match_times = [regex]::Matches($status_node.ChildNodes[1].ChildNodes['#text'].Text, '\d{2}:\d{2}:\d{2}')
        $match_offsets = [regex]::Matches($status_node.ChildNodes[1].ChildNodes['#text'].Text, '\+\d{4}')
        "egais cert_age PKI $(if($status_node.ChildNodes[0].ChildNodes[0].Attributes['class'].Value.Contains('glyphicon-ok')){'OK'}else{'WARNING'}) $($match_dates[0].Value)T$($match_times[0].Value)$($match_offsets[0].Value) $($match_dates[1].Value)T$($match_times[1].Value)$($match_offsets[1].Value)"
        $idx += 1
        $status_node = $status_nodes[$idx]
        $match_dates = [regex]::Matches($status_node.ChildNodes[1].ChildNodes['#text'].Text, '\d{4}-\d{2}-\d{2}')
        $match_times = [regex]::Matches($status_node.ChildNodes[1].ChildNodes['#text'].Text, '\d{2}:\d{2}:\d{2}')
        $match_offsets = [regex]::Matches($status_node.ChildNodes[1].ChildNodes['#text'].Text, '\+\d{4}')
        "egais cert_age GOST $(if($status_node.ChildNodes[0].ChildNodes[0].Attributes['class'].Value.Contains('glyphicon-ok')){'OK'}else{'WARNING'}) $($match_dates[0].Value)T$($match_times[0].Value)$($match_offsets[0].Value) $($match_dates[1].Value)T$($match_times[1].Value)$($match_offsets[1].Value)"
        $inc_doc_tbl = $wr.DocumentNode.SelectNodes('//div[@class="container"]/div[@class="tab-content"]/div[@id="menu5"]/div[@class="tbl-pane"]/table[@id="table-out"]')
#        $inc_doc_json = (Invoke-WebRequest "$url/$($inc_doc_tbl[0].Attributes['data-url'].Value)?order=asc&limit=1&offset=0" -UseBasicParsing).Content
#        $inc_doc_json_parsed = $inc_doc_json | ConvertFrom-Json
#        if ($inc_doc_json_parsed.total -eq 0)
#        {
#            "egais incoming_docs OK"
#        }
#        else
#        {
#            "egais incoming_docs WARNING $($inc_doc_json_parsed.rows[0].timestamp.Replace(' ','T'))"
#        }
        $status_nodes = $null
    }
    if ($inc_doc_tbl -ne $null)
    {
        try{
            $json1_str = (Invoke-WebRequest "$url/$($inc_doc_tbl[0].Attributes['data-url'].Value)?order=asc&limit=1&offset=0" -UseBasicParsing).Content
        }catch{
            $ErrorActionPreference = $prevEAP
            return
        }
        $json1 = ConvertFrom-Json $json1_str
        if ($json1.total -eq 0)
        {
            "egais incoming_docs OK"
        }
        else
        {
            try{
                $json2_str = (Invoke-WebRequest "$url/$($inc_doc_tbl[0].Attributes['data-url'].Value)?order=asc&limit=$($json1.total)&offset=0" -UseBasicParsing).Content
            }catch{
                $ErrorActionPreference = $prevEAP
                return
            }
            $json2 = ConvertFrom-Json $json2_str
            $arDocs = $json2.rows | select id, type, state, timestamp
            $arDocsUnprocessed = $arDocs | ?{$_.state -eq 0}
            if ($arDocsUnprocessed -eq $null)
            {
                "egais incoming_docs OK"
            }
            else
            {
                "egais incoming_docs WARNING $($arDocsUnprocessed[0].timestamp.Replace(' ','T'))"
            }
        }
    }
}
else
{
    "egais transport_version WARNING HTTP error $($web.StatusCode)"
}
$ErrorActionPreference = $prevEAP

