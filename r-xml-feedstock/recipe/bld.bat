move Rextsoft\include\libxml2\libxml Rextsoft\include
mkdir "%PREFIX%\Rextsoft"
robocopy /E Rextsoft "%PREFIX%\Rextsoft"
"%R%" CMD INSTALL --build .
IF %ERRORLEVEL% NEQ 0 exit 1
