<#
.DESCRIPTION
    Build source code repository that has previously been cloned. Ideally before this artifact is called all packages used by the repo have already been restored using windows-msbuild-env-invokecommand artifact.
.PARAMETER RepoRoot
    Full path to the repo's root directory.
.PARAMETER AdditionalRepoFeeds
    Optional comma separated list of feeds that are used when getting packages for the repo outside of nuget.config.
.PARAMETER InitBuildScript
    Optional CMD command line or a batch script (potentially with arguments) used to initialize the build environment before running the build. By default Visual Studio's VsDevCmd.bat is used for MSBuild repos.
.PARAMETER RunBuildScript
    Optional CMD command line or a batch script (potentially with arguments) used to run the build. By default MSBuild is invoked for MSBuild repos.
.PARAMETER AdditionalBuildArguments
    Optional command line arguments passed to MSBuild
.PARAMETER Dirs
    Optional comma separated list of sub directories in the repo to build. By default the whole repo is built from the root.
#>

param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][String] $RepoRoot,
    [Parameter(Mandatory = $false)][String] $InitBuildScript,
    [Parameter(Mandatory = $false)][String] $RunBuildScript,
    [Parameter(Mandatory = $false)][String] $AdditionalBuildArguments,
    [Parameter(Mandatory = $false)] [String] $AdditionalRepoFeeds,
    [Parameter(Mandatory = $false)][String] $Dirs
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$buildScriptPath = (Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName() + '.cmd'))
try {

    Write-Host "Getting ready to build MSBuild repo"

    if ([string]::IsNullOrEmpty($InitBuildScript)) {
        Import-Module -Force (Join-Path $(Split-Path -Parent $PSScriptRoot) '_common/windows-msbuild-utils.psm1')
        $InitBuildScript = """$(Get-LatestVisualStudioDeveloperEnvironmentScriptPath)"""
    }

    $buildCommand = $RunBuildScript
    if ([string]::IsNullOrEmpty($buildCommand)) {
        $buildCommand = "msbuild $AdditionalBuildArguments"
    }

    $buildScript = @(
        "@ECHO ON"
        "@ECHO Executing build script $buildScriptPath",
        "@ECHO === Setting up the build environment with '$InitBuildScript'",
        # Do not wrap the script string in quotes here because it may contain arguments
        "CALL $InitBuildScript" 
        "IF ERRORLEVEL 1 EXIT 1"
        "powershell -noprofile ""$(Join-Path $PSScriptRoot 'build-state-reporter.ps1')"""
    )

    [Array] $buildDirs = @( $RepoRoot )
    if (-not [string]::IsNullOrEmpty($Dirs)) {
        $buildDirs = $Dirs -Split ','
    }

    foreach ($buildDir in $buildDirs) {
        if ([System.IO.Path]::IsPathRooted($buildDir)) {
            $buildDirFullPath = $buildDir
        }
        else {
            $buildDirFullPath = (Join-Path $RepoRoot $buildDir)
        }

        $buildScript += @(
            "@ECHO ON"
            "@ECHO === Building directory $buildDirFullPath"
            "CD /D ""$buildDirFullPath""",
            "CALL $buildCommand",
            "IF ERRORLEVEL 1 EXIT 1"
        )
    }

    $buildScript += @(
        "@ECHO === Successfully completed building the repo"
    )

    Set-Content -Path $buildScriptPath -Value $buildScript
    Write-Host "--- Content of generated build script $buildScriptPath :"
    Get-Content $buildScriptPath
    Write-Host "--- End of generated build script $buildScriptPath"

    $invokecommandScriptPath = (Join-Path $(Split-Path -Parent $PSScriptRoot) 'windows-msbuild-env-invokecommand/windows-msbuild-env-invokecommand.ps1')
    & $invokecommandScriptPath  -RepoRoot $RepoRoot -Script $buildScriptPath
}
catch {
    Write-Error "!!! [ERROR] Unhandled exception:`n$_`n$($_.ScriptStackTrace)" -ErrorAction Stop
}

Remove-Item $buildScriptPath -Force -ErrorAction SilentlyContinue
