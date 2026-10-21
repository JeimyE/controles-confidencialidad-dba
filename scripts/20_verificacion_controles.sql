-- =====================================================================
-- 20_verificacion_controles.sql
-- SCRIPT DE VERIFICACION - 15 controles observables + 3 complementarios
-- Ejecutar : sqlplus / as sysdba   (o SQL Developer como SYS, F5)
-- Salida   : evidencia_controles.txt  (adjuntar al informe)
--
-- Fase 1: vistas de nivel CDB (keystore, archivos de contrasenas,
--         backups, version).  Fase 2: controles dentro de XEPDB1.
-- Cada bloque indica: control, que se verifica y el resultado esperado.
-- =====================================================================
SET ECHO OFF
SET FEEDBACK ON
SET LINESIZE 220
SET PAGESIZE 200
SET TRIMSPOOL ON
SET SERVEROUTPUT ON

SPOOL evidencia_controles.txt

PROMPT ================================================================
PROMPT  VERIFICACION DE CONTROLES ISO/IEC 27001:2022 - ORACLE 21c XE
PROMPT ================================================================
SELECT TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24:MI:SS TZH:TZM') AS fecha_ejecucion,
       SYS_CONTEXT('USERENV','SESSION_USER') AS ejecutado_por,
       SYS_CONTEXT('USERENV','DB_NAME')      AS base
FROM dual;

-- =====================================================================
-- FASE 1 - CDB$ROOT
-- =====================================================================
ALTER SESSION SET CONTAINER = CDB$ROOT;

PROMPT
PROMPT ===============================================================
PROMPT [A.8.24] Uso de criptografia - Keystore TDE  (PRB-01)
PROMPT Esperado: STATUS=OPEN, WALLET_TYPE=AUTOLOGIN en CDB y XEPDB1
PROMPT ===============================================================
COLUMN wrl_parameter FORMAT A35
SELECT w.con_id, NVL(p.name,'CDB$ROOT') AS contenedor, w.wrl_type,
       w.wrl_parameter, w.status, w.wallet_type, w.keystore_mode
FROM   v$encryption_wallet w
LEFT   JOIN v$pdbs p ON p.con_id = w.con_id
ORDER  BY w.con_id;

PROMPT
PROMPT ===============================================================
PROMPT [A.8.2] Derechos de acceso privilegiado - Privilegios administrativos
PROMPT Esperado: solo SYS con SYSDBA; C##BACKUP_OP=SYSBACKUP; C##KEY_ADMIN=SYSKM
PROMPT ===============================================================
COLUMN username FORMAT A20
SELECT username, sysdba, sysoper, sysbackup, sysdg, syskm, account_status
FROM   v$pwfile_users
ORDER  BY username;

PROMPT
PROMPT ===============================================================
PROMPT [A.8.13] Copias de seguridad - Configuracion y piezas cifradas (PRB-16)
PROMPT Esperado: ARCHIVELOG; ENCRYPTION FOR DATABASE ON; ENCRYPTED=YES
PROMPT ===============================================================
SELECT log_mode FROM v$database;

COLUMN name FORMAT A35
COLUMN value FORMAT A40
SELECT name, value FROM v$rman_configuration ORDER BY name;

PROMPT Piezas de respaldo disponibles (ultimos 7 dias) con tipo y cifrado
PROMPT B = D (datos/controlfile) o L (archivelogs); CON = incluye controlfile
COLUMN handle FORMAT A60
SELECT TO_CHAR(p.completion_time,'YYYY-MM-DD HH24:MI') AS fecha, p.encrypted,
       b.backup_type, b.controlfile_included, p.handle
FROM   v$backup_piece p
JOIN   v$backup_set b ON b.set_stamp = p.set_stamp AND b.set_count = p.set_count
WHERE  p.status = 'A' AND p.completion_time > SYSDATE - 7
ORDER  BY p.completion_time;

COLUMN input_type FORMAT A12
SELECT session_key, input_type, status,
       TO_CHAR(start_time,'YYYY-MM-DD HH24:MI') AS inicio,
       output_bytes_display AS tamano
FROM   v$rman_backup_job_details
ORDER  BY session_key DESC
FETCH FIRST 5 ROWS ONLY;

PROMPT
PROMPT ===============================================================
PROMPT [A.8.8 - complementario] Gestion de vulnerabilidades tecnicas (PRB-23)
PROMPT Esperado (hallazgo): XE no recibe Release Updates -> estado PARCIAL
PROMPT ===============================================================
COLUMN banner_full FORMAT A90
SELECT banner_full FROM v$version;
COLUMN description FORMAT A60
SELECT patch_id, action, status, description,
       TO_CHAR(action_time,'YYYY-MM-DD') AS fecha
FROM   dba_registry_sqlpatch
ORDER  BY action_time;

-- =====================================================================
-- FASE 2 - XEPDB1
-- =====================================================================
ALTER SESSION SET CONTAINER = XEPDB1;

PROMPT
PROMPT ===============================================================
PROMPT [A.8.24 - complementario] Tablespaces cifrados (PRB-02)
PROMPT Esperado: TS_CONF_ENC ENCRYPTED=YES, algoritmo AES256
PROMPT ===============================================================
SELECT t.name AS tablespace, e.encryptionalg, e.status
FROM   v$encrypted_tablespaces e
JOIN   v$tablespace t ON t.ts# = e.ts# AND t.con_id = e.con_id;

SELECT owner, COUNT(*) AS tablas,
       SUM(CASE WHEN tablespace_name = 'TS_CONF_ENC' THEN 1 ELSE 0 END) AS en_ts_cifrado
FROM   dba_tables
WHERE  owner = 'APP_CONF'
GROUP  BY owner;

PROMPT
PROMPT ===============================================================
PROMPT [A.5.12] Clasificacion de la informacion (PRB-21)
PROMPT Esperado: toda columna CONFIDENCIAL/RESTRINGIDO protegida con Redaction
PROMPT          (NOMBRE e ID son INTERNO: protegidos por VPD/roles)
PROMPT ===============================================================
COLUMN columna FORMAT A12
COLUMN nivel FORMAT A13
COLUMN categoria_dato FORMAT A42
SELECT c.columna, c.nivel, c.categoria_dato,
       CASE WHEN rc.column_name IS NOT NULL THEN 'REDACTADA' ELSE '** SIN REDACCION **' END AS proteccion
FROM   app_conf.catalogo_clasificacion c
LEFT   JOIN redaction_columns rc
       ON rc.object_owner = 'APP_CONF' AND rc.object_name = c.tabla AND rc.column_name = c.columna
ORDER  BY c.nivel, c.columna;

PROMPT Columnas CONFIDENCIAL/RESTRINGIDO sin redaccion (esperado: 0)
SELECT COUNT(*) AS sin_proteccion
FROM   app_conf.catalogo_clasificacion c
WHERE  c.nivel IN ('CONFIDENCIAL','RESTRINGIDO')
AND    NOT EXISTS (SELECT 1 FROM redaction_columns rc
                   WHERE rc.object_owner = 'APP_CONF' AND rc.object_name = c.tabla
                   AND   rc.column_name = c.columna);

COLUMN comments FORMAT A70
SELECT column_name, comments FROM dba_col_comments
WHERE  owner = 'APP_CONF' AND table_name = 'CLIENTES' AND comments IS NOT NULL;

PROMPT
PROMPT ===============================================================
PROMPT [A.5.15] Control de acceso - Privilegios directos a usuarios (PRB-11)
PROMPT Esperado: 0 filas (todo se asigna mediante roles)
PROMPT ===============================================================
COLUMN grantee FORMAT A18
COLUMN privilegio FORMAT A50
SELECT grantee, privilege AS privilegio, 'SISTEMA' AS tipo
FROM   dba_sys_privs
WHERE  grantee IN (SELECT username FROM dba_users
                   WHERE oracle_maintained = 'N' AND username NOT IN ('PDBADMIN'))
UNION ALL
SELECT grantee, privilege || ' ON ' || owner || '.' || table_name, 'OBJETO'
FROM   dba_tab_privs
WHERE  grantee IN (SELECT username FROM dba_users
                   WHERE oracle_maintained = 'N' AND username NOT IN ('PDBADMIN'));

PROMPT Privilegios por rol de aplicacion
COLUMN role FORMAT A20
SELECT grantee AS role, privilege AS privilegio, 'SISTEMA' AS tipo
FROM   dba_sys_privs WHERE grantee LIKE 'ROL\_%\_CONF' ESCAPE '\'
UNION ALL
SELECT grantee, privilege || ' ON ' || owner || '.' || table_name, 'OBJETO'
FROM   dba_tab_privs WHERE grantee LIKE 'ROL\_%\_CONF' ESCAPE '\'
UNION ALL
SELECT grantee, granted_role, 'ROL'
FROM   dba_role_privs WHERE grantee LIKE 'ROL\_%\_CONF' ESCAPE '\'
ORDER  BY 1, 3, 2;

PROMPT
PROMPT ===============================================================
PROMPT [A.5.16] Gestion de identidades - Cuentas no mantenidas por Oracle
PROMPT Esperado: cuentas nominativas, PERFIL_CONF, esquemas en NONE (sin login)
PROMPT ===============================================================
COLUMN profile FORMAT A14
COLUMN last_login FORMAT A20
SELECT username, account_status, profile, authentication_type,
       TO_CHAR(created,'YYYY-MM-DD') AS creada,
       TO_CHAR(last_login,'YYYY-MM-DD HH24:MI') AS last_login
FROM   dba_users
WHERE  oracle_maintained = 'N'
ORDER  BY username;

PROMPT Cuentas abiertas sin uso en 90 dias (esperado: 0)
SELECT username FROM dba_users
WHERE  oracle_maintained = 'N' AND account_status = 'OPEN'
AND    authentication_type = 'PASSWORD'
AND    (last_login IS NULL AND created < SYSDATE - 90
        OR last_login < SYSTIMESTAMP - INTERVAL '90' DAY);

PROMPT
PROMPT ===============================================================
PROMPT [A.5.17] Informacion de autenticacion (PRB-13)
PROMPT Esperado: perfil con complejidad y bloqueo; 0 cuentas abiertas con
PROMPT           contrasena por defecto
PROMPT ===============================================================
COLUMN resource_name FORMAT A28
COLUMN limit FORMAT A32
SELECT resource_name, limit FROM dba_profiles
WHERE  profile = 'PERFIL_CONF' AND resource_type = 'PASSWORD'
ORDER  BY resource_name;

SELECT d.username, u.account_status
FROM   dba_users_with_defpwd d
JOIN   dba_users u ON u.username = d.username
WHERE  u.account_status = 'OPEN';

PROMPT
PROMPT ===============================================================
PROMPT [A.5.18] Derechos de acceso - Revision de privilegios efectivos
PROMPT Esperado: cada usuario solo con el rol de su funcion
PROMPT ===============================================================
COLUMN usuario FORMAT A16
COLUMN rol_heredado FORMAT A28
SELECT CONNECT_BY_ROOT grantee AS usuario,
       LPAD(' ', 2*(LEVEL-1)) || granted_role AS rol_heredado,
       admin_option
FROM   dba_role_privs
START  WITH grantee IN (SELECT username FROM dba_users WHERE oracle_maintained = 'N')
CONNECT BY PRIOR granted_role = grantee;

PROMPT
PROMPT ===============================================================
PROMPT [A.5.33] Proteccion de registros - Retencion de auditoria (PRB-15)
PROMPT Esperado: job de purga ENABLED; marca de archivo ~365 dias atras;
PROMPT           AUDIT_ADMIN solo en cuentas de Oracle
PROMPT ===============================================================
COLUMN job_name FORMAT A28
SELECT job_name, job_status, job_frequency FROM dba_audit_mgmt_cleanup_jobs;
SELECT audit_trail, last_archive_ts FROM dba_audit_mgmt_last_arch_ts;
SELECT job_name, enabled, state, repeat_interval
FROM   dba_scheduler_jobs WHERE job_name = 'JOB_RETENCION_AUDIT_CONF';
SELECT grantee, granted_role FROM dba_role_privs
WHERE  granted_role IN ('AUDIT_ADMIN','AUDIT_VIEWER') ORDER BY granted_role, grantee;

PROMPT
PROMPT ===============================================================
PROMPT [A.8.2] Derechos de acceso privilegiado - Rol DBA y privilegios ANY (PRB-12)
PROMPT Esperado: DBA solo en SYS/SYSTEM; ningun usuario de aplicacion con ANY
PROMPT ===============================================================
SELECT grantee, granted_role, admin_option FROM dba_role_privs
WHERE  granted_role IN ('DBA','PDB_DBA','DATAPUMP_EXP_FULL_DATABASE','EXP_FULL_DATABASE')
ORDER  BY granted_role, grantee;

SELECT grantee, privilege FROM dba_sys_privs
WHERE  privilege LIKE '%ANY%'
AND    grantee IN (SELECT username FROM dba_users WHERE oracle_maintained = 'N'
                   UNION SELECT role FROM dba_roles WHERE oracle_maintained = 'N');

PROMPT
PROMPT ===============================================================
PROMPT [A.8.3] Restriccion de acceso a la informacion - VPD
PROMPT Esperado: POL_VPD_CLIENTES habilitada para SEL/INS/UPD/DEL
PROMPT ===============================================================
COLUMN object_name FORMAT A12
COLUMN policy_name FORMAT A20
COLUMN function FORMAT A18
SELECT object_name, policy_name, function, sel, ins, upd, del, enable
FROM   dba_policies WHERE object_owner = 'APP_CONF';

PROMPT Usuarios exentos de VPD (esperado: solo cuentas de Oracle)
SELECT grantee FROM dba_sys_privs WHERE privilege = 'EXEMPT ACCESS POLICY';

PROMPT
PROMPT ===============================================================
PROMPT [A.8.5] Autenticacion segura (PRB-10)
PROMPT Esperado: verificadores solo 12C; bloqueo a los 3 intentos
PROMPT ===============================================================
COLUMN password_versions FORMAT A18
SELECT username, password_versions, profile FROM dba_users
WHERE  oracle_maintained = 'N' AND authentication_type = 'PASSWORD'
ORDER  BY username;

SELECT p.limit AS failed_login_attempts FROM dba_profiles p
WHERE  p.profile = 'PERFIL_CONF' AND p.resource_name = 'FAILED_LOGIN_ATTEMPTS';

COLUMN name FORMAT A35
COLUMN value FORMAT A20
SELECT name, value FROM v$parameter
WHERE  name IN ('sec_max_failed_login_attempts','remote_login_passwordfile',
                'sec_protocol_error_further_action','resource_limit');

PROMPT
PROMPT ===============================================================
PROMPT [A.8.10] Eliminacion de informacion (PRB-09)
PROMPT Esperado: papelera vacia para APP_CONF; supresiones registradas con hash
PROMPT ===============================================================
SELECT COUNT(*) AS objetos_en_papelera FROM dba_recyclebin WHERE owner = 'APP_CONF';
SELECT tipo, COUNT(*) AS registros, MAX(fecha) AS ultima
FROM   app_conf.registro_supresiones GROUP BY tipo;
PROMPT Clientes que exceden el plazo de 5 anios (esperado: 0)
SELECT COUNT(*) AS fuera_de_plazo FROM app_conf.clientes
WHERE  fecha_ultima_actividad < ADD_MONTHS(SYSDATE, -60);

PROMPT
PROMPT ===============================================================
PROMPT [A.8.11] Enmascaramiento de datos - Data Redaction (PRB-04)
PROMPT Esperado: POL_REDACT_CLIENTES habilitada sobre 5 columnas
PROMPT ===============================================================
COLUMN expression FORMAT A60
COLUMN function_parameters FORMAT A36
COLUMN column_name FORMAT A10
SELECT object_name, policy_name, expression, enable FROM redaction_policies;
SELECT column_name, function_type, function_parameters
FROM   redaction_columns WHERE object_owner = 'APP_CONF' ORDER BY column_name;

PROMPT
PROMPT ===============================================================
PROMPT [A.8.12] Prevencion de fuga de datos (PRB-22)
PROMPT Esperado: EXEMPT REDACTION POLICY y exportacion completa solo en
PROMPT           roles/cuentas de Oracle; PUBLIC sin UTL_FILE/UTL_HTTP/UTL_TCP/UTL_SMTP
PROMPT           (si PUBLIC conserva alguno -> documentar como PARCIAL)
PROMPT ===============================================================
SELECT grantee, privilege FROM dba_sys_privs
WHERE  privilege IN ('EXEMPT REDACTION POLICY','EXEMPT ACCESS POLICY',
                     'SELECT ANY TABLE','EXPORT FULL DATABASE')
ORDER  BY privilege, grantee;

SELECT grantee, table_name, privilege FROM dba_tab_privs
WHERE  grantee = 'PUBLIC'
AND    table_name IN ('UTL_FILE','UTL_HTTP','UTL_TCP','UTL_SMTP','UTL_INADDR','DBMS_LDAP');

SELECT policy_name, enabled_option FROM audit_unified_enabled_policies
WHERE  policy_name = 'POL_AUD_EXPORTACIONES';

PROMPT
PROMPT ===============================================================
PROMPT [A.8.33 - complementario] Informacion de prueba (PRB-20)
PROMPT Esperado: 0 coincidencias de datos reales en DEV
PROMPT ===============================================================
SELECT
  (SELECT COUNT(*) FROM app_conf_dev.clientes d JOIN app_conf.clientes p ON d.cedula  = p.cedula)  AS cedulas_reales,
  (SELECT COUNT(*) FROM app_conf_dev.clientes d JOIN app_conf.clientes p ON d.nombre  = p.nombre)  AS nombres_reales,
  (SELECT COUNT(*) FROM app_conf_dev.clientes d JOIN app_conf.clientes p ON d.email   = p.email)   AS emails_reales,
  (SELECT COUNT(*) FROM app_conf_dev.clientes d JOIN app_conf.clientes p ON d.tarjeta = p.tarjeta) AS tarjetas_reales
FROM dual;

PROMPT
PROMPT ===============================================================
PROMPT [A.8.15] Registro (logging) - Politicas y eventos (PRB-14)
PROMPT Esperado: politicas POL_AUD_* y ORA_LOGON_FAILURES activas;
PROMPT           eventos de las pruebas presentes
PROMPT ===============================================================
COLUMN policy_name FORMAT A26
SELECT policy_name, enabled_option, entity_name, success, failure
FROM   audit_unified_enabled_policies ORDER BY policy_name;

COLUMN dbusername FORMAT A15
COLUMN action_name FORMAT A16
COLUMN object_name FORMAT A12
COLUMN unified_audit_policies FORMAT A26
SELECT TO_CHAR(event_timestamp,'YYYY-MM-DD HH24:MI:SS') AS fecha,
       dbusername, action_name, object_schema, object_name,
       return_code, unified_audit_policies
FROM   unified_audit_trail
WHERE  object_schema = 'APP_CONF'
   OR  (action_name = 'LOGON' AND return_code <> 0)
ORDER  BY event_timestamp DESC
FETCH FIRST 25 ROWS ONLY;

SELECT action_name, return_code, COUNT(*) AS eventos
FROM   unified_audit_trail
WHERE  event_timestamp > SYSTIMESTAMP - INTERVAL '1' DAY
GROUP  BY action_name, return_code
ORDER  BY eventos DESC;

PROMPT
PROMPT ===============================================================
PROMPT [A.8.20] Seguridad de redes - Sesiones TCP cifradas (PRB-18)
PROMPT Esperado: sesiones remotas con "AES256 Encryption" y "SHA256 Crypto"
PROMPT (deje SQL Developer conectado por TCP mientras corre este script)
PROMPT ===============================================================
COLUMN network_service_banner FORMAT A80
SELECT DISTINCT s.username, ci.network_service_banner
FROM   v$session s
JOIN   v$session_connect_info ci ON ci.sid = s.sid AND ci.serial# = s.serial#
WHERE  s.username IS NOT NULL
AND    (ci.network_service_banner LIKE '%Encryption service adapter%'
     OR ci.network_service_banner LIKE '%Crypto-checksumming service adapter%');

PROMPT
PROMPT ================================================================
PROMPT  FIN DE LA VERIFICACION
PROMPT ================================================================
SPOOL OFF
SET ECHO ON
