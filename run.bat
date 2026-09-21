@echo off
if not exist sim mkdir sim
iverilog -g2005 -Wall -o sim\flowguard.out rtl\*.v tb\*.v
if errorlevel 1 exit /b 1
vvp sim\flowguard.out
