# Write nfo metadata file if html .txt from sort_jav.py exists
function Set-JAVNfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false, Position=0)]
        [System.IO.FileInfo]$FilePath,
        [Switch]$KeepMetadataTxt
    )
    # Write txt metadata file paths to $HTMLMetadata
    $HTMLMetadata = Get-ChildItem -Path $FilePath -Recurse | Where-Object { $_.Name -match '[a-zA-Z]{2,7}-[0-9]{2,7}(.*.txt)' } | Select Name, BaseName, FullName, Directory, Length
    # Write each nfo file
    foreach ($MetadataFile in $HTMLMetadata) {
        $Count = 1
        $HTMLContent = Get-Content $MetadataFile.FullName
        $NfoName = $MetadataFile.BaseName + '.nfo'
        $NfoPath = Join-Path -Path $MetadataFile.Directory -ChildPath $NfoName

        $Title = $HTMLContent -match '<title>(.*) - JAVLibrary<\/title>'
        $TitleFixed = (($Title -replace '<title>', '') -replace  '- JAVLibrary</title>', '').Trim()
        $ReleaseDate = ($HTMLContent -match '<td class="text">\d{4}-\d{2}-\d{2}<\/td>').Split(('<td class="text">','</td>'), 'None')[1]
        $ReleaseYear = ($ReleaseDate.Split('-'))[0]
        $Studio = (($HTMLContent -match '<a href="vl_maker\.php\?m=[\w\d]{1,10}" rel="tag">(.*)<\/a>')).Split(('rel="tag">', '</a> &nbsp'), 'None')[1]

        # Add various metadata
        Set-Content -Path $NfoPath -Value '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        Add-Content -Path $NfoPath -Value '<movie>'
        Add-Content -Path $NfoPath -Value "    <title>$TitleFixed</title>"
        Add-Content -Path $NfoPath -Value "    <year>$ReleaseYear</year>"
        Add-Content -Path $NfoPath -Value "    <releasedate>$ReleaseDate</releasedate>"
        Add-Content -Path $NfoPath -Value "    <studio>$Studio</studio>"

        # Add actress metadata
        $Actors = ((($HTMLContent -match '<ActressSorted>(.*)<\/ActressSorted>') -replace '<ActressSorted>', '') -replace '</ActressSorted>', '').Split('|') | Sort-Object
        foreach ($Actor in $Actors) {
                    $Content = @(
                    "    <actor>"
                    "        <name>$Actor</name>"
                    "    </actor>"
            )
            Add-Content -Path $NfoPath -Value $Content
        }
        # End file
        Add-Content -Path $NfoPath -Value '</movie>'
        Write-Host "[$Count] Wrote .nfo metadata for file $TitleFixed"

        # Remove html txt file
        if (!($KeepMetadataTxt)) {
            Remove-Item -LiteralPath $MetadataFile.FullName
        }
        $Count++
    }

    # Clean up
    Get-Variable | Remove-Variable -ErrorAction Ignore
}