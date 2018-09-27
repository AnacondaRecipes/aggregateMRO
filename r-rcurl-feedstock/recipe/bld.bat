copy %SRC_DIR%\libcurl\lib\x64\libcurl-dualssl.a %SRC_DIR%\libcurl\lib\x64\libcurl.a
copy %SRC_DIR%\libcurl\lib\i386\libcurl-dualssl.a %SRC_DIR%\libcurl\lib\i386\libcurl.a

set LIB_CURL=%SRC_DIR:\=/%/libcurl
"%R%" CMD INSTALL --build .
IF %ERRORLEVEL% NEQ 0 exit 1
