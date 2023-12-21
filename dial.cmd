@echo off
set directoryOfThisScript=%~dp0
pwsh -c "%directoryOfThisScript%dial.ps1" %*
