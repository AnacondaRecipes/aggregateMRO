del /s /q %PREFIX%\lib\R\bin\x64\Rblas.dll
if %ErrorLevel% neq 0 exit /b $ErrorLevel%
del /s /q %PREFIX%\lib\R\bin\x64\Rlapack.dll
if %ErrorLevel% neq 0 exit /b $ErrorLevel%
copy %PREFIX%\lib\R\bin\x64\Rblas.dll.mkl %PREFIX%\lib\R\bin\x64\Rblas.dll
if %ErrorLevel% neq 0 exit /b $ErrorLevel%
copy %PREFIX%\lib\R\bin\x64\Rlapack.dll.mkl %PREFIX%\lib\R\bin\x64\Rlapack.dll
if %ErrorLevel% neq 0 exit /b $ErrorLevel%
