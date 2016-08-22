@if "%SCM_TRACE_LEVEL%" NEQ "4" @echo off

echo "**********************"
echo "Post Deployment Script"
echo "**********************"

:: 1. SET
:: ----------------------
:: Post Deploy Script
:: Version: 1.0.0
:: Martin Schray
:: Execute the build steps for Stationfy
:: ----------------------

setlocal enabledelayedexpansion

:: 2. Setup vars

set NODE_CMD= node
set NPM_CMD= npm
set RM_CMD= rm
   
:::::::::::::::::::::::::::::::::::::::::::
:: Post Deployment execution
:::::::::::::::::::::::::::::::::::::::::::

:Deployment
echo Handling node.js deployment.

echo "Running rm -rf /public..."
pushd "%DEPLOYMENT_TARGET%"
call :ExecuteCmd !RM_CMD! -rf %DEPLOYMENT_TARGET%/public 
IF !ERRORLEVEL! NEQ 0 goto error
popd

echo "Running NPM RUN minify..."
pushd "%DEPLOYMENT_TARGET%"
call :ExecuteCmd !NPM_CMD! run minify 
IF !ERRORLEVEL! NEQ 0 goto error
popd

:: 4. Post deployment actions
:: Webpack
echo "Running webpack..." 
pushd "%DEPLOYMENT_TARGET%"
call :ExecuteCmd !NODE_CMD! %DEPLOYMENT_TARGET%\node_modules\webpack\bin\webpack.js --verbose  --display-error-details --config %DEPLOYMENT_TARGET%\webpack.config.js 
IF !ERRORLEVEL! NEQ 0 goto error
popd

echo "Running NPM RUN Favicon..."
pushd "%DEPLOYMENT_TARGET%"
call :ExecuteCmd !NPM_CMD! run favicon  
IF !ERRORLEVEL! NEQ 0 goto error
popd

echo "Running NPM RUN vendors..."
pushd "%DEPLOYMENT_TARGET%"
call :ExecuteCmd !NPM_CMD! run vendors 
IF !ERRORLEVEL! NEQ 0 goto error
popd

echo "Running NPM run Build:CSS..."
pushd "%DEPLOYMENT_TARGET%"
call :ExecuteCmd !NPM_CMD! run build:css 
IF !ERRORLEVEL! NEQ 0 goto error
popd

echo "Running NPM run hashmark.js ..."
:: this one doesn't do any conversions using ES6 directly so I run it with Node 6.2.2
pushd "%DEPLOYMENT_TARGET%"
call :ExecuteCmd "D:\\Program Files (x86)\\nodejs\\6.2.2\node" hashmark.js 
IF !ERRORLEVEL! NEQ 0 goto error
popd

echo "Custom postdeploy.cmd completed ...\n\n"

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
