-- =====================================================================
-- 02_cdb_separacion_funciones.sql
-- Controles: A.8.2 (derechos de acceso privilegiado), A.5.15
-- Tarea DBA: T-02 Gestion de privilegios
-- Ejecutar : sqlplus / as sysdba     (contenedor CDB$ROOT)
--
-- Separacion de funciones: el respaldo y la gestion de llaves NO se
-- hacen con SYSDBA, sino con privilegios administrativos acotados:
--   C##BACKUP_OP -> SYSBACKUP (solo RMAN / respaldo y recuperacion)
--   C##KEY_ADMIN -> SYSKM     (solo gestion del keystore TDE)
-- =====================================================================
SET ECHO ON
SET LINESIZE 200

DEFINE PWD_BACKUP = 'Bk7#Rm9$Xp2026'
DEFINE PWD_KEYADM = 'Km4#Tz8$Wq2026'

ALTER SESSION SET CONTAINER = CDB$ROOT;

CREATE USER c##backup_op IDENTIFIED BY "&PWD_BACKUP" CONTAINER = ALL;
GRANT CREATE SESSION TO c##backup_op CONTAINER = ALL;
GRANT SYSBACKUP      TO c##backup_op CONTAINER = ALL;

CREATE USER c##key_admin IDENTIFIED BY "&PWD_KEYADM" CONTAINER = ALL;
GRANT CREATE SESSION TO c##key_admin CONTAINER = ALL;
GRANT SYSKM          TO c##key_admin CONTAINER = ALL;

-- Evidencia (A.8.2): quien tiene privilegios administrativos
COLUMN username FORMAT A20
SELECT username, sysdba, sysoper, sysbackup, sysdg, syskm, con_id
FROM   v$pwfile_users
ORDER  BY username;

-- Resultado esperado: SYS con SYSDBA; C##BACKUP_OP solo SYSBACKUP;
-- C##KEY_ADMIN solo SYSKM. Ninguna otra cuenta con SYSDBA.
