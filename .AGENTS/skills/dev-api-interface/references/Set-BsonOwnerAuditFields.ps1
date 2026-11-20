#Requires -Version 5.1
function Set-BsonOwnerAuditFields {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Json,

        [string] $UserId = '1003153',
        [string] $UserName = ''
    )

    if ([string]::IsNullOrWhiteSpace($UserName)) {
        $UserName = [System.Text.Encoding]::UTF8.GetString(
            [byte[]](0xE7, 0x86, 0x8A, 0xE6, 0x80, 0x9D, 0xE6, 0x80, 0x9D)
        )
    }

    $j = $Json
    $j = [regex]::Replace($j, '"creator":"\d+"', ('"creator":"' + $UserId + '"'))
    $j = [regex]::Replace($j, '"editor":"\d+"', ('"editor":"' + $UserId + '"'))
    $patName = [char]34 + 'creatorName' + [char]34 + ':' + [char]34 + '[^' + [char]34 + ']*' + [char]34
    $patEditorName = [char]34 + 'editorName' + [char]34 + ':' + [char]34 + '[^' + [char]34 + ']*' + [char]34
    $j = [regex]::Replace($j, $patName, ('"creatorName":"' + $UserName + '"'))
    $j = [regex]::Replace($j, $patEditorName, ('"editorName":"' + $UserName + '"'))
    return $j
}
