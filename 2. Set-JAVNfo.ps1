# Write nfo metadata file if html .txt from sort_jav.py exists
function Set-JAVNfo {
    [CmdletBinding()]
    param(
        [Parameter()]
        [System.IO.FileInfo]$FilePath = ((Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath 'settings_sort_jav.ini')) -match '^path').Split('=')[1],
        [Parameter()]
        [Switch]$Prompt
    )

    function Show-FileChanges {
        # Display file changes to host
        $Table = @{Expression = { $_.Index }; Label = "#"; Width = 2 },
        @{Expression = { $_.Name }; Label = "Name"; Width = 25 },
        @{Expression = { $_.Path }; Label = "Directory" }
        $FileObject | Sort-Object Index | Format-Table -Property $Table | Out-Host
    }

    # Options from settings_sort_jav.ini
    $SettingsPath = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath 'settings_sort_jav.ini')
    $KeepMetadataTxt = ((Get-Content $SettingsPath) -match '^keep-metadata-txt').Split('=')[1]
    $AddGenres = ((Get-Content $SettingsPath) -match '^include-genre-metadata').Split('=')[1]
    $AddTags = ((Get-Content $SettingsPath) -match '^include-tag-metadata').Split('=')[1]
    $AddTitle = ((Get-Content $SettingsPath) -match '^include-video-title').Split('=')[1]
    $PartDelimiter = ((Get-Content $SettingsPath) -match '^delimiter-between-multiple-videos').Split('=')[1]
    $NameSetting = ((Get-Content $SettingsPath) -match '^actress-before-video-number').Split('=')[1]

    # Write txt metadata file paths to $HtmlMetadata
    $HtmlMetadata = Get-ChildItem -LiteralPath $FilePath -Recurse | Where-Object { $_.Name -match '[a-zA-Z]{1,8}-[0-9]{1,8}(.*.txt)' -or $_.Name -match 't28(.*).txt' } | Select-Object Name, BaseName, FullName, Directory
    if ($null -eq $HtmlMetadata) {
        Write-Warning 'No metadata files found! Exiting...'
        pause
    }

    else {
        # Create table to show files being written
        $Index = 1
        $FileObject = @()
        foreach ($File in $HtmlMetadata) {
            $FileObject += New-Object -TypeName psobject -Property @{
                Index = $Index
                Name  = $File.BaseName
                Path  = $File.Directory
            }
            $Index++
        }
        # Default prompt yes
        $Input = 'y'
        if ($Prompt) {
            Write-Output "Metadata to be written:"
            Show-FileChanges
            Write-Output 'Do you want to write nfo metadata for these files?'
            Write-Output 'Confirm changes?'
            $Input = Read-Host -Prompt '[Y] Yes    [N] No    (default is "N")'
        }
        if ($Input -like 'y' -or $Input -like 'yes') {
            Write-Output "Writing metadata .nfo files in path: $FilePath ..."
            # Write each nfo file
            $Count = 1
            $Total = $HtmlMetadata.Count
            foreach ($MetadataFile in $HtmlMetadata) {
                # Read html txt
                $FileLocation = $MetadataFile.FullName
                # Read and encode html in UTF8 for better reading of asian characters and symbols
                $HtmlContent = Get-Content -LiteralPath $FileLocation -Encoding UTF8
                $FileName = $MetadataFile.BaseName
                $NfoName = $MetadataFile.BaseName + '.nfo'
                $NfoPath = Join-Path -Path $MetadataFile.Directory -ChildPath $NfoName
                
                # Get video title name from html with regex
                $Title = ($HtmlContent -match '<title>(.*) - JAVLibrary<\/title>') -replace ' [\W]', ''
                # Replace [\W] removes all special characters in the title
                $TitleFixed = (($Title -replace '<title>', '') -replace '- JAVLibrary</title>', '').Trim()

                # Check if the video has multiple parts
                # If it does, write the part number to a variable
                if ($NameSetting -like 'true') {
                    $PartNumber = $FileName[-1]
                }
                else {
                    if ($PartDelimiter -like '-') {
                        $PartNumber = ($FileName -split ($PartDelimiter))[2]
                    }
                    else {
                        $PartNumber = ($FileName -split ($PartDelimiter))[1]
                    }
                }

                # Since the above does a split to find if it's a part
                # Match if the part number found is a 1 digit number
                if ($PartNumber -match '^\d$') {
                    $Temp = $TitleFixed.Split(' ')[0] + ' ' + "($PartNumber) "
                    $Temp2 = $TitleFixed.Split(' ')[1..$TitleFixed.Length] -join ' '
                    # Replace [\W] removes all special characters in the title
                    # If html file is detected as multi-part, create a new title as "VidID (Part#) Title"
                    $TitleFixed = ($Temp + $Temp2)
                }
                $FinalTitle = $TitleFixed
                $ReleaseDate = ($HtmlContent -match '<td class="text">\d{4}-\d{2}-\d{2}<\/td>').Split(('<td class="text">', '</td>'), 'None')[1]
                $ReleaseYear = ($ReleaseDate.Split('-'))[0]
                $Studio = (($HtmlContent -match '<a href="vl_maker\.php\?m=[\w\d]{1,10}" rel="tag">(.*)<\/a>')).Split(('rel="tag">', '</a> &nbsp'), 'None')[1]
                $Genres = (($HtmlContent -match 'rel="category tag">(.*)<\/a><\/span><\/td>') -Split 'rel="category tag">')
                
                # Write metadata to file
                Set-Content -LiteralPath $NfoPath -Value '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' -Force
                Add-Content -LiteralPath $NfoPath -Value '<movie>'
                if ($AddTitle -like 'true') {
                    Add-Content -LiteralPath $NfoPath -Value "    <title>$FinalTitle</title>"
                }
                Add-Content -LiteralPath $NfoPath -Value "    <year>$ReleaseYear</year>"
                Add-Content -LiteralPath $NfoPath -Value "    <releasedate>$ReleaseDate</releasedate>"
                Add-Content -LiteralPath $NfoPath -Value "    <studio>$Studio</studio>"
                if ($AddGenres -like 'true') {
                    foreach ($Genre in $Genres[1..($Genres.Length - 1)]) {
                        $GenreString = (($Genre.Split('<'))[0]).Trim()
                        Add-Content -LiteralPath $NfoPath -Value "    <genre>$GenreString</genre>"
                    }
                }
                if ($AddTags -like 'true') {
                    foreach ($Genre in $Genres[1..($Genres.Length - 1)]) {
                        $GenreString = (($Genre.Split('<'))[0]).Trim()
                        Add-Content -LiteralPath $NfoPath -Value "    <tag>$GenreString</tag>"
                    }
                }
                # Add actress metadata
                $ActorSplitString = '<span class="star">'
                $ActorSplitHtml = $HtmlContent -split $ActorSplitString
                $Actors = @()
                foreach ($Section in $ActorSplitHtml) {
                    $FullName = (($Section -split "rel=`"tag`">")[1] -split "<\/a><\/span>")[0]
                    if ($FullName -ne '') {
                        if ($FullName.Length -lt 25) {
                            $Actors += $FullName
                        }
                    }
                }
                foreach ($Actor in $Actors) {
                    $Content = @(
                        "    <actor>"
                        "        <name>$Actor</name>"
                        "        <role>Actor</role>"
                        "    </actor>"
                    )
                    Add-Content -LiteralPath $NfoPath -Value $Content
                }
                # End file
                Add-Content -LiteralPath $NfoPath -Value '</movie>'
                Write-Output "($Count of $Total) $FileName .nfo processed..."
                # Remove html txt file
                if ($KeepMetadataTxt -eq 'false') {
                    Remove-Item -LiteralPath $MetadataFile.FullName
                }
                $Count++
            }
            pause
        }
        else {
            Write-Warning 'Cancelled by user input. Exiting...'
            pause
        }
    }
}

Set-JAVNfo -Prompt