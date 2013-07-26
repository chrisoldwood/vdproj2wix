vdproj2wix v1.0
===============

Introduction
------------

This PowerShell script (vdproj2wix.ps1) is a very simple one for converting a
Visual Studio setup project (aka a .vdproj file) into a WiX format one (i.e.
a .wxs file). Although there are other more fully featured tools for creating
a .wxs file, such as from an existing MSI binary, I wanted something that gave
me a bare bones .wxs file that ignored all the boilerplate code that Visual
Studio adds by default. As a server-side chappy all the MSI installers I create
are simple ones designed to deploy a bunch of files into a folder - this script
targets that scenario.

Documentation
-------------

There is a manual: vdproj2wix.html.

Contact Details
------------------

Email: gort@cix.co.uk
Web:   http://www.chrisoldwood.com

Chris Oldwood 
31st October 2011
