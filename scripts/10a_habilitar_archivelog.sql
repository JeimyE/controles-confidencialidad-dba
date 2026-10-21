-- =====================================================================
-- 10a_habilitar_archivelog.sql
-- Control  : A.8.13 (copias de seguridad)
-- Tarea DBA: T-06 Backup
-- Ejecutar : sqlplus / as sysdba   (CDB$ROOT)
--
-- XE se instala en NOARCHIVELOG. Para respaldos en caliente con RMAN se
-- habilita ARCHIVELOG. La base se reinicia.
-- =====================================================================
SET ECHO ON
ALTER SESSION SET CONTAINER = CDB$ROOT;

SHUTDOWN IMMEDIATE
STARTUP MOUNT
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
ALTER PLUGGABLE DATABASE ALL OPEN;

ARCHIVE LOG LIST
SELECT log_mode FROM v$database;
-- Resultado esperado: LOG_MODE = ARCHIVELOG
