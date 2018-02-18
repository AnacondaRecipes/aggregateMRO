del /s /q %PREFIX%\lib\R\bin\x64\Rblas.dll
if %ErrorLevel% neq 0 exit /b $ErrorLevel%
del /s /q %PREFIX%\lib\R\bin\x64\Rlapack.dll
if %ErrorLevel% neq 0 exit /b $ErrorLevel%
copy %PREFIX%\lib\R\bin\x64\Rblas.dll.nomkl %PREFIX%\lib\R\bin\x64\Rblas.dll
if %ErrorLevel% neq 0 exit /b $ErrorLevel%
copy %PREFIX%\lib\R\bin\x64\Rlapack.dll.nomkl %PREFIX%\lib\R\bin\x64\Rlapack.dll
if %ErrorLevel% neq 0 exit /b $ErrorLevel%
