################################################################################
#
# \file		vdproj2wix.ps1
# \brief	Converts a VS setup project (.vdproj) to a WiX project (.wix).
# \author	Chris Oldwood (gort@cix.co.uk | www.cix.co.uk/~gort)
# \version	0.1
#
# This is a simple script that does a trivial transformation of a Visual Studio
# setup project file (.vdproj) to a WiX format file. It was only designed to
# put the skeleton of the WiX file in place, i.e. the GUID's and files, and so
# it assumes a single install folder based on the default. It also does not
# handle registry keys, UI etc.
#
################################################################################

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
		write-output "vdproj2wix v0.1"
		write-output "(C) Chris Oldwood 2011 (gort@cix.co.uk)"
	}
	else
	{
		write-output "ERROR: Invalid command line"
	}

	write-output ""
	write-output "Usage: vdproj2wix <vdproj file>"
	write-output ""
	write-output "e.g. PowerShell -File vdproj2wix.ps1 Test.vdproj"
	exit 1
}

# Format output filename
$vdprojFile = $args[0]
$wixFolder = split-path -parent $vdprojFile

$wixFile = split-path -leaf $vdprojFile
$wixFile = $wixFile -replace '\.vdproj','.wix'

if ($wixFolder -ne '')
{
	$wixFile = join-path $wixFolder $wixFile
}

write-output "Input:  $vdprojFile"
write-output "Ouptut: $wixFile"

# Initialise content variables
$productId = '<unknown>'
$productName = '<unknown>'
$languageId = '1033'
$productVersion = '<unknown>'
$manufacturer = '<unknown>'
$upgradeCode = '<unknown>'
$packageCode = '<unknown>'
$files = @()

# Initialise section variables
$inProductSection = $false
$inFileSection = $false

#
# Parse the .vdproj file
#
$lines = get-content $vdprojFile

foreach ($line in $lines)
{
	if ($line -match '^\s*"(?<section>\w+)"$')
	{
		# Handle begin/end of each section
		if ($matches.section -eq 'Product')
		{
			$inProductSection = $true
		}
		elseif ($matches.section -eq 'File')
		{
			$inFileSection = $true
		}
		else
		{
			$inProductSection = $false
			$inFileSection = $false
		}
	}
	elseif ($inProductSection -eq $true)
	{
		if ($line -match '^\s*"ProductCode" = "8:{(?<value>.*)}"$')
		{
			$productId = $matches.value
		}
		elseif ($line -match '^\s*"ProductName" = "8:(?<value>.*)"$')
		{
			$productName = $matches.value
		}
		elseif ($line -match '^\s*"ProductVersion" = "8:(?<value>.*)"$')
		{
			$productVersion = $matches.value
		}
		elseif ($line -match '^\s*"Manufacturer" = "8:(?<value>.*)"$')
		{
			$manufacturer = $matches.value
		}
		elseif ($line -match '^\s*"UpgradeCode" = "8:{(?<value>.*)}"$')
		{
			$upgradeCode = $matches.value
		}
		elseif ($line -match '^\s*"PackageCode" = "8:{(?<value>.*)}"$')
		{
			$packageCode = $matches.value
		}
	}
	elseif ($inFileSection -eq $true)
	{
		if ($line -match '^\s*"SourcePath" = "8:(?<value>.*)"$')
		{
			$files += $matches.value
		}
	}
}

#
# Write the WiX file
#
"<?xml version='1.0'?>"															| out-file $wixFile
"<Wix xmlns='http://schemas.microsoft.com/wix/2006/wi'>"						| out-file $wixFile -append
"    <Product Id='$productId'"													| out-file $wixFile -append
"             Name='$productName'"												| out-file $wixFile -append
"             Language='$languageId'"											| out-file $wixFile -append
"             Version='$productVersion'"										| out-file $wixFile -append
"             Manufacturer='$manufacturer'"										| out-file $wixFile -append
"             UpgradeCode='$upgradeCode'>"										| out-file $wixFile -append
""																				| out-file $wixFile -append
"        <Package Compressed='yes'/>"											| out-file $wixFile -append
""																				| out-file $wixFile -append
"        <Media Id='1' Cabinet='product.cab' EmbedCab='yes'/>"					| out-file $wixFile -append
""																				| out-file $wixFile -append
"        <Directory Id='TARGETDIR' Name='SourceDir'>"							| out-file $wixFile -append
"            <Directory Id='ProgramFilesFolder' Name='PFiles'>"					| out-file $wixFile -append
"                <Directory Id='ManufacturerDir' Name='$manufacturer'>"			| out-file $wixFile -append
"                    <Directory Id='ProductDir' Name='$productName'>"			| out-file $wixFile -append
""																				| out-file $wixFile -append
"                        <Component Id='MyComponent' Guid='$packageCode'>"		| out-file $wixFile -append
""																				| out-file $wixFile -append

foreach ($file in $files)
{
	$fileId = split-path -leaf $file
	$fileName = split-path -leaf $file
	$fileSource = $file
"                            <File Id='$fileId' Name='$fileName' DiskId='1' Source='$fileSource' />"	| out-file $wixFile -append
}

""																				| out-file $wixFile -append
"                        </Component>"											| out-file $wixFile -append
""																				| out-file $wixFile -append
"                    </Directory>"												| out-file $wixFile -append
"                </Directory>"													| out-file $wixFile -append
"            </Directory>"														| out-file $wixFile -append
"        </Directory>"															| out-file $wixFile -append
""																				| out-file $wixFile -append
"        <Feature Id='MyFeature' Level='1'>"									| out-file $wixFile -append
"            <ComponentRef Id='MyComponent'/>"									| out-file $wixFile -append
"        </Feature>"															| out-file $wixFile -append
""																				| out-file $wixFile -append
"    </Product>"																| out-file $wixFile -append
"</Wix>"																		| out-file $wixFile -append
