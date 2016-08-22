echo "Starting Custom Deployment Script"
@if "%SCM_TRACE_LEVEL%" NEQ "4" @echo off

:: ----------------------
:: KUDU Deployment Script
:: Version: 1.0.7
:: Changes by Martin Schray to remove node_modules dir, install everything not just production and finally 
:: copy the postdeploy.cmd file into location to be executed by Kudu 
:: ----------------------

:: Prerequisites
:: -------------

:: Verify node.js installed
where node 2>nul >nul
IF %ERRORLEVEL% NEQ 0 (
  echo Missing node.js executable, please install node.js, if already installed make sure it can be reached from current environment.
  goto error
)

:: Setup
:: -----

setlocal enabledelayedexpansion

SET ARTIFACTS=%~dp0%..\artifacts

IF NOT DEFINED DEPLOYMENT_SOURCE (
  SET DEPLOYMENT_SOURCE=%~dp0%.
)

IF NOT DEFINED DEPLOYMENT_TARGET (
  SET DEPLOYMENT_TARGET=%ARTIFACTS%\wwwroot
)

IF NOT DEFINED NEXT_MANIFEST_PATH (
  SET NEXT_MANIFEST_PATH=%ARTIFACTS%\manifest

  IF NOT DEFINED PREVIOUS_MANIFEST_PATH (
    SET PREVIOUS_MANIFEST_PATH=%ARTIFACTS%\manifest
  )
)

IF NOT DEFINED KUDU_SYNC_CMD (
  :: Install kudu sync
  echo Installing Kudu Sync
  call npm install kudusync -g --silent
  IF !ERRORLEVEL! NEQ 0 goto error

  :: Locally just running "kuduSync" would also work
  SET KUDU_SYNC_CMD=%appdata%\npm\kuduSync.cmd
)
goto Deployment

:: Utility Functions
:: -----------------

:SelectNodeVersion

IF DEFINED KUDU_SELECT_NODE_VERSION_CMD (
  :: The following are done only on Windows Azure Websites environment
  call %KUDU_SELECT_NODE_VERSION_CMD% "%DEPLOYMENT_SOURCE%" "%DEPLOYMENT_TARGET%" "%DEPLOYMENT_TEMP%"
  IF !ERRORLEVEL! NEQ 0 goto error

  IF EXIST "%DEPLOYMENT_TEMP%\__nodeVersion.tmp" (
    SET /p NODE_EXE=<"%DEPLOYMENT_TEMP%\__nodeVersion.tmp"
    IF !ERRORLEVEL! NEQ 0 goto error
  )

  IF EXIST "%DEPLOYMENT_TEMP%\__npmVersion.tmp" (
    SET /p NPM_JS_PATH=<"%DEPLOYMENT_TEMP%\__npmVersion.tmp"
    IF !ERRORLEVEL! NEQ 0 goto error
  )

  IF NOT DEFINED NODE_EXE (
    SET NODE_EXE=node
  )

  SET NPM_CMD="!NODE_EXE!" "!NPM_JS_PATH!"
) ELSE (
  SET NPM_CMD=npm
  SET NODE_EXE=node
)

goto :EOF

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Deployment
:: ----------

:Deployment
echo Handling node.js deployment.

:: 1. KuduSync
IF /I "%IN_PLACE_DEPLOYMENT%" NEQ "1" (
  call :ExecuteCmd "%KUDU_SYNC_CMD%" -v 50 -f "%DEPLOYMENT_SOURCE%" -t "%DEPLOYMENT_TARGET%" -n "%NEXT_MANIFEST_PATH%" -p "%PREVIOUS_MANIFEST_PATH%" -i ".git;.hg;.deployment;deploy.cmd"
  IF !ERRORLEVEL! NEQ 0 goto error
)

:: 2. Select node version
call :SelectNodeVersion

:: 2.5 Remove nodule_modules to take care of the file name collisions (and failure) that are seen if node_modules isn't removed.
:: https://docs.npmjs.com/cli/cache
  pushd "%DEPLOYMENT_TARGET%"
  :: Setup the commands I'll be using to first move and remove the node_modules directory
  set MV_CMD= move
  set RM_CMD= start /b rm
  :: set supports getting a random value.  I am appending a letter to ensure the dir name starts with a char
  set RAND=a%RANDOM%

  ::echo "Random value is " %RAND%

:: 2.7 check if node_modules is exists.  If so move it and delete it.
IF EXIST "%DEPLOYMENT_TARGET%\node_modules" (
  echo "Clean (rename and remove) existing node_modules directory..."
  pushd "%DEPLOYMENT_TARGET%"
  :: Need this MKDIR to ensure the move works.  The second level (e.g. tmp) must exist for move to work.    
  MKDIR %HOME%\tmp\%RAND%

  :: delete takes forever, but a move is instanteous.  So use a move with a background delete.  That way the install can move forward.
  call :ExecuteCmd !MV_CMD! %DEPLOYMENT_TARGET%\node_modules %HOME%\tmp\%RAND%
  IF !ERRORLEVEL! NEQ 0 goto error
  :: If home\tmp exists than start the background delete of home\tmp that way anything under home\tmp is removed
  IF EXIST "%HOME%\tmp" (
    echo "start the background delete..."
    call :ExecuteCmd !RM_CMD! -rf %HOME%\tmp\
    IF !ERRORLEVEL! NEQ 0 echo "ERROR: unable to delete the moved node_modules directory"
  )
    popd
)

:: 3. Install npm packages both dev and production
IF EXIST "%DEPLOYMENT_TARGET%\package.json" (
  pushd "%DEPLOYMENT_TARGET%"
  ::  This was call :ExecuteCmd !NPM_CMD! install --production but we need the dev packages to do the build after deploy
  call :ExecuteCmd !NPM_CMD! ---d install
  IF !ERRORLEVEL! NEQ 0 goto error
  popd
)

:: 4. Post deployment actions
:: copy the post deployment script into place so its executed automatically by Kudu
echo "copy the post deployment script into place"
pushd "%DEPLOYMENT_TARGET%"
IF NOT EXIST %DEPLOYMENT_TARGET%\..\deployments\tools\PostDeploymentActions (
  echo "create PostDeploymentActions"
  call :ExecuteCmd mkdir %DEPLOYMENT_TARGET%\..\deployments\tools\PostDeploymentActions
  IF !ERRORLEVEL! NEQ 0 goto error
) ELSE (
  echo "PostDeploymentActions already exists"
)
call :ExecuteCmd copy %DEPLOYMENT_SOURCE%\PostDeploy.cmd %DEPLOYMENT_TARGET%\..\deployments\tools\PostDeploymentActions\
IF !ERRORLEVEL! NEQ 0 goto error
popd




::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
goto end

:: Execute command routine that will echo out when error
:ExecuteCmd
setlocal
set _CMD_=%*
call %_CMD_%
if "%ERRORLEVEL%" NEQ "0" echo Failed exitCode=%ERRORLEVEL%, command=%_CMD_%
exit /b %ERRORLEVEL%

:error
endlocal
echo An error has occurred during web site deployment.
call :exitSetErrorLevel
call :exitFromFunction 2>nul

:exitSetErrorLevel
exit /b 1

:exitFromFunction
()

:end
endlocal
echo Finished successfully.
