-- =====================================================================
-- 01_cdb_tde_keystore.sql
-- Proyecto : Controles ISO/IEC 27001:2022 - Confidencialidad en Oracle
-- Controles: A.8.24 (uso de criptografia) / soporte de A.8.13
-- Tarea DBA: T-04 Cifrado TDE
-- Ejecutar : sqlplus / as sysdba     (contenedor CDB$ROOT)
-- Motor    : Oracle Database 21c XE (multitenant: CDB XE + PDB XEPDB1)
--
-- REQUISITO PREVIO (PowerShell como administrador):
--     mkdir C:\oracle_wallet\XE\tde
-- La base se REINICIA en este script (WALLET_ROOT es estatico).
-- =====================================================================
SET ECHO ON
SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 100

DEFINE WALLET_DIR = 'C:\oracle_wallet\XE'
DEFINE WALLET_PWD = 'Wallet#Conf$2026'

ALTER SESSION SET CONTAINER = CDB$ROOT;

-- 1. Ubicacion del keystore (parametro estatico -> requiere reinicio)
ALTER SYSTEM SET WALLET_ROOT = '&WALLET_DIR' SCOPE = SPFILE;

SHUTDOWN IMMEDIATE
STARTUP
ALTER PLUGGABLE DATABASE ALL OPEN;

-- 2. Tipo de keystore: archivo (software keystore)
ALTER SYSTEM SET TDE_CONFIGURATION = 'KEYSTORE_CONFIGURATION=FILE' SCOPE = BOTH;

-- 3. Crear keystore protegido por contrasena (modo unido: CDB + PDBs)
ADMINISTER KEY MANAGEMENT CREATE KEYSTORE IDENTIFIED BY "&WALLET_PWD";

-- 4. Abrir keystore en todos los contenedores
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN
  IDENTIFIED BY "&WALLET_PWD" CONTAINER = ALL;

-- 5. Crear la llave maestra (con respaldo del keystore antes del cambio)
ADMINISTER KEY MANAGEMENT SET KEY
  IDENTIFIED BY "&WALLET_PWD" WITH BACKUP USING 'llave_maestra_inicial'
  CONTAINER = ALL;

-- 6. Keystore auto-login: se abre solo al reiniciar la instancia
ADMINISTER KEY MANAGEMENT CREATE AUTO_LOGIN KEYSTORE
  FROM KEYSTORE IDENTIFIED BY "&WALLET_PWD";

-- 7. Evidencia (A.8.24)
COLUMN wrl_parameter FORMAT A40
SELECT con_id, wrl_type, wrl_parameter, status, wallet_type, keystore_mode
FROM   v$encryption_wallet
ORDER  BY con_id;

-- Resultado esperado: STATUS = OPEN en CON_ID 1 y en XEPDB1.
-- IMPORTANTE: guardar la contrasena del keystore fuera de la base
-- (sin ella no se pueden restaurar backups cifrados).
