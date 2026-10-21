-- =====================================================================
-- 04_pdb_usuarios_roles_perfiles.sql
-- Controles: A.5.15 (control de acceso), A.5.16 (gestion de identidades),
--            A.5.17 (informacion de autenticacion), A.5.18 (derechos de
--            acceso), A.8.2 (acceso privilegiado), A.8.5 (autenticacion segura)
-- Tareas   : T-01 Usuarios, T-02 Privilegios, T-03 Autenticacion
-- Ejecutar : sqlplus / as sysdba   (cambia a XEPDB1)
--
-- Principio de minimo privilegio: los usuarios NO reciben privilegios
-- directos; todo se asigna mediante roles por funcion.
-- =====================================================================
SET ECHO ON
SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 100

-- Contrasenas de laboratorio (cumplen ORA12C_STRONG_VERIFY_FUNCTION:
-- >= 9 caracteres, 2 mayusculas, 2 minusculas, 2 digitos, 2 especiales)
DEFINE PWD_ANALISTA = 'Kx7#Lm9$Qr2026'
DEFINE PWD_OPERADOR = 'Pt5#Vn3$Hs2026'
DEFINE PWD_AUDITOR  = 'Jw8#Cd4$Bf2026'
DEFINE PWD_DBAJR    = 'Ny6#Gk2$Zm2026'

ALTER SESSION SET CONTAINER = XEPDB1;

-- 0. Verificar que exista la funcion de complejidad
--    (si no aparece, ejecutar:  @?/rdbms/admin/catpvf.sql  en XEPDB1)
SELECT object_name, status FROM dba_objects
WHERE  owner = 'SYS' AND object_name = 'ORA12C_STRONG_VERIFY_FUNCTION';

-- 1. Perfil de seguridad (A.5.17 / A.8.5)
CREATE PROFILE perfil_conf LIMIT
  FAILED_LOGIN_ATTEMPTS     3
  PASSWORD_LOCK_TIME        1/24
  PASSWORD_LIFE_TIME        90
  PASSWORD_GRACE_TIME       7
  PASSWORD_REUSE_TIME       365
  PASSWORD_REUSE_MAX        5
  INACTIVE_ACCOUNT_TIME     90
  SESSIONS_PER_USER         3
  IDLE_TIME                 15
  PASSWORD_VERIFY_FUNCTION  ora12c_strong_verify_function;

-- 2. Roles por funcion (A.5.15 - RBAC)
-- rol_analista_conf : solo lectura (datos enmascarados + VPD)
-- rol_operador_conf : operacion, lectura/escritura sin borrar
-- rol_auditor_conf  : revision de auditoria y diccionario
-- rol_dba_oper_conf : DBA junior, administracion acotada
-- (SQL*Plus no ejecuta una sentencia si lleva un comentario -- despues del ;)
CREATE ROLE rol_analista_conf;
CREATE ROLE rol_operador_conf;
CREATE ROLE rol_auditor_conf;
CREATE ROLE rol_dba_oper_conf;

GRANT CREATE SESSION TO rol_analista_conf;
GRANT SELECT ON app_conf.clientes TO rol_analista_conf;

GRANT CREATE SESSION TO rol_operador_conf;
GRANT SELECT, INSERT, UPDATE ON app_conf.clientes TO rol_operador_conf;
-- Nota: DELETE no se otorga; la supresion se hace por procedimiento (script 07)

GRANT CREATE SESSION      TO rol_auditor_conf;
GRANT AUDIT_VIEWER        TO rol_auditor_conf;
GRANT SELECT_CATALOG_ROLE TO rol_auditor_conf;

GRANT CREATE SESSION, ALTER USER TO rol_dba_oper_conf;
GRANT SELECT_CATALOG_ROLE        TO rol_dba_oper_conf;

-- 3. Cuentas nominativas con perfil seguro (A.5.16)
CREATE USER u_analista IDENTIFIED BY "&PWD_ANALISTA" PROFILE perfil_conf;
CREATE USER u_operador IDENTIFIED BY "&PWD_OPERADOR" PROFILE perfil_conf;
CREATE USER u_auditor  IDENTIFIED BY "&PWD_AUDITOR"  PROFILE perfil_conf;
CREATE USER u_dba_jr   IDENTIFIED BY "&PWD_DBAJR"    PROFILE perfil_conf;

GRANT rol_analista_conf TO u_analista;
GRANT rol_operador_conf TO u_operador;
GRANT rol_auditor_conf  TO u_auditor;
GRANT rol_dba_oper_conf TO u_dba_jr;

-- 4. Evidencias
COLUMN profile FORMAT A15
COLUMN resource_name FORMAT A30
COLUMN limit FORMAT A35
SELECT resource_name, limit
FROM   dba_profiles
WHERE  profile = 'PERFIL_CONF' AND resource_type = 'PASSWORD'
ORDER  BY resource_name;

COLUMN username FORMAT A15
COLUMN password_versions FORMAT A20
SELECT username, account_status, profile, authentication_type, password_versions
FROM   dba_users
WHERE  oracle_maintained = 'N'
ORDER  BY username;

-- Privilegios directos a usuarios (esperado: 0 filas)
SELECT grantee, privilege FROM dba_sys_privs
WHERE  grantee IN ('U_ANALISTA','U_OPERADOR','U_AUDITOR','U_DBA_JR');
