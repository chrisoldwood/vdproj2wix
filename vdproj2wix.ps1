################################################################################
#
# \file		vdproj2wix.ps1
# \brief	Converts a VS setup project (.vdproj) to a WiX source file (.wxs).
# \author	Chris Oldwood (gort@cix.co.uk | http://www.cix.co.uk/~gort)
# \version	0.9
#
# This script does a trivial transformation of a Visual Studio setup project
# file (.vdproj) to a WiX format file (.wxs). It was only designed to handle
# simple server-side deployments, i.e. the GUID's, folders, files and registry
# keys.
#
################################################################################

set-strictmode -version latest

# Configure error handling
$ErrorActionPreference = 'stop'

trap
{
	write-error $_ -erroraction continue
	exit 1
}

# Validate command line
if ( ($args.count -ne 1) -or ($args[0] -eq '--help') )
{
	if ($args[0] -eq '--help')
	{
		write-output "vdproj2wix v0.9"
		write-output "(C) Chris Oldwood 2011 (gort@cix.co.uk)"
	}
	else
	{
		write-output "ERROR: Invalid command line"
	}

	write-output ""
	write-output "USAGE: vdproj2wix <.vdproj file>"
	write-output ""
	write-output "e.g. PowerShell -File vdproj2wix.ps1 Test.vdproj"
	exit 1
}

# Format output filename
$vdprojFile = $args[0]
$wixFolder = split-path -parent $vdprojFile

$wixFile = split-path -leaf $vdprojFile
$wixFile = $wixFile -replace '\.vdproj','.wxs'

if ($wixFolder -ne '')
{
	$wixFile = join-path $wixFolder $wixFile
}

write-output "Input : $vdprojFile"
write-output "Output: $wixFile"

################################################################################
# Parse the .vdproj file
################################################################################

# Remove the escape characters from the path
function unescapeFilePath($filePath)
{
	return $filePath -replace "\\\\","\"
}

# Initialise content variables
$productId = '<unknown>'
$productName = '<unknown>'
$languageId = '1033'
$productVersion = '<unknown>'
$manufacturer = '<unknown>'
$upgradeCode = '<unknown>'
$packageCode = '<unknown>'
$files = @()
$folders = @()

# Initialise parsing variables
$inProductSection = $false
$inFileSection = $false
$currentFile = $null
$inFolderSection = $false
$currentFolder = $null
$parentIndex = -1
$folderStack = @()
$folderId=''
$guid=''
$defaultLocation = ''
$folderMap = @{}
$nextFolderId = 1
$nextComponentId = 1
$nextFeatureId = 1
$components = @()

# For each line in the .vdproj file...
$lines = get-content $vdprojFile

foreach ($line in $lines)
{
	# Handle entry/exit of the sections we're interested in
	if ($line -match '^\s{8}"(?<section>\w+)"$')
	{
		if ($matches.section -eq 'Product')
		{
			$inProductSection = $true
		}
		elseif ($matches.section -eq 'File')
		{
			$inFileSection = $true
		}
		elseif ($matches.section -eq 'Folder')
		{
			$inFolderSection = $true
		}
		else
		{
			$inProductSection = $false
			$inFileSection = $false
			$currentFile = $null
			$inFolderSection = $false
			$currentFolder = $null
		}
	}
	# Parse product section
	elseif ($inProductSection -eq $true)
	{
		if ($line -match '^\s{8}"ProductCode" = "8:{(?<value>.*)}"$')
		{
			$productId = $matches.value
		}
		elseif ($line -match '^\s{8}"ProductName" = "8:(?<value>.*)"$')
		{
			$productName = $matches.value
		}
		elseif ($line -match '^\s{8}"ProductVersion" = "8:(?<value>.*)"$')
		{
			$productVersion = $matches.value
		}
		elseif ($line -match '^\s{8}"Manufacturer" = "8:(?<value>.*)"$')
		{
			$manufacturer = $matches.value
		}
		elseif ($line -match '^\s{8}"UpgradeCode" = "8:{(?<value>.*)}"$')
		{
			$upgradeCode = $matches.value
		}
		elseif ($line -match '^\s{8}"PackageCode" = "8:{(?<value>.*)}"$')
		{
			$packageCode = $matches.value
		}
	}
	# Parse files section
	elseif ($inFileSection -eq $true)
	{
		if ($line -match '^\s{12}"SourcePath" = "8:(?<value>.*)"$')
		{
			$currentFile = @{ SourcePath=$matches.value; TargetName=$matches.value; Folder='' }
			$files	  += $currentFile
		}
		elseif ($line -match '^\s{12}"TargetName" = "8:(?<value>.*)"$')
		{
			$currentFile.TargetName = $matches.value
		}
		elseif ($line -match '^\s{12}"Folder" = "8:(?<value>.*)"$')
		{
			$currentFile.Folder = $matches.value
		}
	}
	# Parse folder section
	elseif ($inFolderSection -eq $true)
	{
		# Start of any folder entry?
		if ($line -match '^\s{12,}"\{(?<guid>[A-Z0-9-]+)\}:(?<value>_[A-Z0-9-]+)"$')
		{
			$guid = $matches.guid
			$folderId = $matches.value
			$defaultLocation = ''
		}
		# Start of child folders section?
		elseif ($line -match '^\s{16,}"Folders"$')
		{
			++$parentIndex
		}
		# Matching end of child folders section or the folder itself?
		elseif ( ($line -match '^\s{16,}\}$') -and (($line.indexof('}') % 8) -eq 0) )
		{
			if ($parentIndex -ge 1)
			{
				--$parentIndex
				$folderStack = $folderStack[0..$parentIndex]
			}
			else
			{
				$parentIndex = -1
				$folderStack = @()
			}
		}

		if ($line -match '^\s{12,}"DefaultLocation" = "8:(?<value>.*)"$')
		{
			$defaultLocation = $matches.value
		}
		elseif ($line -match '^\s{12,}"Name" = "8:(?<value>.*)"$')
		{
			$currentFolder = @{ Id=$folderId; Name=$matches.value;
								Property=''; DefaultLocation=$defaultLocation;
								Guid=$guid; Folders=@(); Files=@()
							  }

			if ($parentIndex -lt 0)
			{
				$folders += $currentFolder
			}
			else
			{
				$folderStack[$parentIndex].Folders += $currentFolder
			}

			$folderStack += $currentFolder
			$folderMap.$folderId = $currentFolder
		}
		elseif ($line -match '^\s{12,}"Property" = "8:(?<value>.*)"$')
		{
			$currentFolder.Property = $matches.value

			if ($currentFolder.Property -eq 'TARGETDIR')
			{
				$currentFolder.Id   = $currentFolder.Property
				$currentFolder.Name = 'SourceDir'
				
			}
		}
	}
}

# Sort the files by filename to make checking easier
$files = $files | sort -property { split-path -leaf $_.SourcePath }

# Link the files to their parent folders
foreach ($file in $files)
{
	$parent = $file.Folder

	($folderMap.$parent).Files += $file
}

# Expand the DefaultLocation folder into a folder tree
foreach ($folder in $folders)
{
	if ($folder.DefaultLocation -ne '')
	{
		$installFolder = unescapeFilePath $folder.DefaultLocation
		$installFolder = $installFolder -replace '\[ProgramFilesFolder\]',"ProgramFilesFolder\"
		$installFolder = $installFolder -replace '\[Manufacturer\]',"$manufacturer"
		$installFolder = $installFolder -replace '\[ProductName\]',"$productName"
		
		$childFolders  = $installFolder.Split('\\')
		
		foreach ($child in $childFolders)
		{
			# Insert new child folder between the current one and its children
			$newFolder = @{ Id=$child; Name=$child; Property=''; DefaultLocation='';
							Guid=$folder.Guid; Folders=$folder.Folders; Files=$folder.Files }
			
			$folder.Guid     = ''
			$folder.Folders  = @()
			$folder.Files    = @()
			$folder.Folders += $newFolder
			
			$folder = $newFolder
		}
	}
}

################################################################################
# Write the WiX file
################################################################################

# Write the tree of folders and files
function writeFileSystemTree($tree, $indent, $file)
{
	foreach ($folder in $tree)
	{
		# Don't output empty common folders
		if ( $folder.Name.startswith('#') -and ($folder.Folders.length -eq 0) )
		{
			continue;
		}

		if ( ($folder.Id -eq 'TARGETDIR') -or ($folder.Id -eq 'ProgramFilesFolder') )
		{
			$folderId = $folder.Id
		}
		else
		{
			$folderId = "_{0}" -f $script:nextFolderId++
		}
		
		"{0}<Directory Name=`"{1}`" Id=`"{2}`">" -f $indent,$folder.Name,$folderId | out-file -encoding ASCII $file -append

		if ($folder.Folders.length -ne 0)
		{
			$indent += '    '

			writeFileSystemTree $folder.Folders $indent $file

			$indent = $indent.substring(0, $indent.length-4)
		}

		if ($folder.Files.length -ne 0)
		{
			$indent += '    '
			$guid = $folder.Guid
			$componentId = "_{0}" -f $script:nextComponentId++

			#""																		| out-file -encoding ASCII $wixFile -append
			"{0}<Component Id=`"$componentId`" Guid=`"$guid`">" -f $indent			| out-file -encoding ASCII $wixFile -append
			#""																		| out-file -encoding ASCII $wixFile -append

			foreach ($file in $folder.Files)
			{
				$path = unescapeFilePath $file.SourcePath
				$name = split-path -leaf $path

				if ($file.TargetName -ne $name)
				{
					$name = $file.TargetName

					"{0}    <File Source=`"$path`" Name=`"$name`"/>" -f $indent		| out-file -encoding ASCII $wixFile -append
				}
				else
				{
					"{0}    <File Source=`"$path`"/>" -f $indent					| out-file -encoding ASCII $wixFile -append
				}
			}

			#""																		| out-file -encoding ASCII $wixFile -append
			"{0}</Component>" -f $indent											| out-file -encoding ASCII $wixFile -append
			#""																		| out-file -encoding ASCII $wixFile -append

			$script:components += @{ Id=$componentId; Guid=$guid }

			$indent = $indent.substring(0, $indent.length-4)
		}

		"{0}</Directory>" -f $indent | out-file -encoding ASCII $wixFile -append
	}

}

# Generate the .wxs file
"<?xml version=`"1.0`"?>"														| out-file -encoding ASCII $wixFile
"<Wix xmlns=`"http://schemas.microsoft.com/wix/2006/wi`">"						| out-file -encoding ASCII $wixFile -append
"    <Product Id=`"$productId`""												| out-file -encoding ASCII $wixFile -append
"             Name=`"$productName`""											| out-file -encoding ASCII $wixFile -append
"             Language=`"$languageId`""											| out-file -encoding ASCII $wixFile -append
"             Version=`"$productVersion`""										| out-file -encoding ASCII $wixFile -append
"             Manufacturer=`"$manufacturer`""									| out-file -encoding ASCII $wixFile -append
"             UpgradeCode=`"$upgradeCode`">"									| out-file -encoding ASCII $wixFile -append
""																				| out-file -encoding ASCII $wixFile -append
"        <Package Compressed=`"yes`"/>"											| out-file -encoding ASCII $wixFile -append
""																				| out-file -encoding ASCII $wixFile -append
"        <Media Id=`"1`" Cabinet=`"product.cab`" EmbedCab=`"yes`"/>"			| out-file -encoding ASCII $wixFile -append
""																				| out-file -encoding ASCII $wixFile -append

writeFileSystemTree $folders '        ' $wixFile

$featureId = "_{0}" -f $nextFeatureId

""																				| out-file -encoding ASCII $wixFile -append
"        <Feature Id=`"$featureId`" Level=`"1`">"								| out-file -encoding ASCII $wixFile -append

foreach ($component in $components)
{
	$id = $component.Id

"            <ComponentRef Id=`"$id`"/>"										| out-file -encoding ASCII $wixFile -append
}

"        </Feature>"															| out-file -encoding ASCII $wixFile -append
""																				| out-file -encoding ASCII $wixFile -append
"    </Product>"																| out-file -encoding ASCII $wixFile -append
"</Wix>"																		| out-file -encoding ASCII $wixFile -append
