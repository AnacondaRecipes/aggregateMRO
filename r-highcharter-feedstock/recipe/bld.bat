if "%target_platform%" == "win-64" goto skip_source_build
"%R%" CMD INSTALL --build .
IF %ERRORLEVEL% NEQ 0 exit 1
exit 0
:skip_source_build
mkdir %PREFIX%\lib\R\library
robocopy /E . "%PREFIX%\lib\R\library\highcharter"
if %ERRORLEVEL% NEQ 1 exit 1
exit 0
