-- =====================================================================
-- 21_pruebas_funcionales.sql
-- BATERIA DE PRUEBAS FUNCIONALES (positivas y negativas)
-- Ejecutar : en SQL*Plus desde PowerShell, en la misma maquina del servidor:
--              sqlplus /nolog @21_pruebas_funcionales.sql
-- Salida   : evidencia_pruebas.txt
--
-- Las conexiones van por TCP (EZConnect) a XEPDB1, asi tambien se
-- prueba el cifrado de red. Los errores ORA- de las pruebas NEGATIVAS
-- son el resultado ESPERADO: el script continua ante errores.
-- =====================================================================
SET ECHO ON
SET FEEDBACK ON
SET LINESIZE 200
SET PAGESIZE 100
SET TRIMSPOOL ON
WHENEVER SQLERROR CONTINUE

DEFINE SRV          = '//localhost:1521/XEPDB1'
DEFINE PWD_ANALISTA = 'Kx7#Lm9$Qr2026'
DEFINE PWD_OPERADOR = 'Pt5#Vn3$Hs2026'
DEFINE PWD_AUDITOR  = 'Jw8#Cd4$Bf2026'
DEFINE PWD_DEV      = 'Dv3#Hx7$Lp2026'

-- Preparacion (fuera de la evidencia): deja el script repetible.
-- Reinserta el titular de PRB-09b si ya fue suprimido y desbloquea al analista.
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = XEPDB1;
INSERT INTO app_conf.clientes (cedula, nombre, email, telefono, provincia, salario, tarjeta, fecha_ultima_actividad)
SELECT '305550111','Titular Supresion Solicitada','titular.supresion@correo.cr','87776666','CARTAGO',950000,'5500111122223333',SYSDATE
FROM   dual
WHERE  NOT EXISTS (SELECT 1 FROM app_conf.clientes WHERE cedula = '305550111');
COMMIT;
ALTER USER u_analista ACCOUNT UNLOCK;

SPOOL evidencia_pruebas.txt

COLUMN cedula   FORMAT A12
COLUMN nombre   FORMAT A30
COLUMN email    FORMAT A28
COLUMN telefono FORMAT A9
COLUMN tarjeta  FORMAT A20
COLUMN provincia FORMAT A12

-- =====================================================================
-- ANALISTA (rol de solo lectura, datos enmascarados, filtrado por VPD)
-- =====================================================================
CONNECT u_analista/"&PWD_ANALISTA"@&SRV

PROMPT >>> PRB-04 [A.8.11] Analista consulta datos confidenciales
PROMPT     Esperado: cedula *****NNNN, salario 0, tarjeta ************NNNN,
PROMPT               telefono ****NNNN, email xxxx@dominio
SELECT cedula, nombre, email, telefono, salario, tarjeta
FROM   app_conf.clientes
WHERE  ROWNUM <= 5;

PROMPT >>> PRB-05 [A.8.3] Analista solo ve su region (VPD)
PROMPT     Esperado: una sola fila con PROVINCIA = HEREDIA
SELECT provincia, COUNT(*) AS clientes FROM app_conf.clientes GROUP BY provincia;

PROMPT >>> PRB-06 [A.5.15] Analista intenta modificar datos
PROMPT     Esperado: ORA-01031 privilegios insuficientes
UPDATE app_conf.clientes SET salario = 0 WHERE ROWNUM = 1;

PROMPT >>> PRB-06b [A.8.12] Analista intenta copiar los datos a una tabla propia
PROMPT     Esperado: rechazo. ORA-28081 (Data Redaction impide copiar columnas
PROMPT               ocultas) u ORA-01031 (sin privilegio CREATE TABLE)
CREATE TABLE copia_clientes AS SELECT * FROM app_conf.clientes;

PROMPT >>> PRB-07 [A.5.33] Analista intenta leer la auditoria
PROMPT     Esperado: ORA-00942 la tabla o vista no existe
SELECT COUNT(*) FROM unified_audit_trail;

-- =====================================================================
-- OPERADOR (lectura/escritura, ve datos reales, sin DELETE directo)
-- =====================================================================
CONNECT u_operador/"&PWD_OPERADOR"@&SRV

PROMPT >>> PRB-08 [A.5.15 / A.8.11] Operador ve datos completos y actualiza
PROMPT     Esperado: datos sin enmascarar; UPDATE de 1 fila exitoso
SELECT cedula, nombre, salario, tarjeta FROM app_conf.clientes
WHERE  cedula = '901230456';
UPDATE app_conf.clientes SET telefono = '88887777' WHERE cedula = '901230456';
COMMIT;

PROMPT >>> PRB-09 [A.8.10] Operador intenta DELETE directo
PROMPT     Esperado: ORA-01031 privilegios insuficientes
DELETE FROM app_conf.clientes WHERE cedula = '305550111';

PROMPT >>> PRB-09b [A.8.10] Supresion controlada por procedimiento
PROMPT     Esperado: PL/SQL procedure successfully completed
EXEC app_conf.prc_suprimir_titular('305550111', 'Solicitud de supresion del titular (Ley 8968)');
SELECT COUNT(*) AS sigue_existiendo FROM app_conf.clientes WHERE cedula = '305550111';

-- =====================================================================
-- DESARROLLADOR (solo entorno DEV con datos sinteticos)
-- =====================================================================
CONNECT u_desarrollador/"&PWD_DEV"@&SRV

PROMPT >>> PRB-20 [A.8.33 / A.8.11] Desarrollador sin acceso a produccion
PROMPT     Esperado: ORA-00942 en PROD; datos sinteticos en DEV
SELECT COUNT(*) FROM app_conf.clientes;
SELECT cedula, nombre, email, tarjeta FROM app_conf_dev.clientes WHERE ROWNUM <= 5;

-- =====================================================================
-- PRB-10 [A.8.5] BLOQUEO POR INTENTOS FALLIDOS
-- Esperado: ORA-01017 tres veces y luego ORA-28000 (cuenta bloqueada)
-- aunque la cuarta contrasena sea la correcta.
-- =====================================================================
PROMPT >>> PRB-10 intento 1 (contrasena incorrecta)
CONNECT u_analista/"Incorrecta#01Ab"@&SRV
PROMPT >>> PRB-10 intento 2 (contrasena incorrecta)
CONNECT u_analista/"Incorrecta#02Ab"@&SRV
PROMPT >>> PRB-10 intento 3 (contrasena incorrecta)
CONNECT u_analista/"Incorrecta#03Ab"@&SRV
PROMPT >>> PRB-10 intento 4 (contrasena CORRECTA) -> esperado ORA-28000
CONNECT u_analista/"&PWD_ANALISTA"@&SRV

-- Restablecer la cuenta (accion del DBA, queda auditada por ORA_ACCOUNT_MGMT)
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = XEPDB1;
SELECT username, account_status FROM dba_users WHERE username = 'U_ANALISTA';
ALTER USER u_analista ACCOUNT UNLOCK;

-- =====================================================================
-- AUDITOR (revisa evidencias, no puede alterarlas)
-- =====================================================================
CONNECT u_auditor/"&PWD_AUDITOR"@&SRV

PROMPT >>> PRB-18 [A.8.20] Cifrado de la sesion TCP actual
PROMPT     Esperado: "AES256 Encryption service adapter" y
PROMPT               "SHA256 Crypto-checksumming service adapter"
COLUMN network_service_banner FORMAT A90
SELECT network_service_banner FROM v$session_connect_info
WHERE  sid = SYS_CONTEXT('USERENV','SID');
SELECT SYS_CONTEXT('USERENV','NETWORK_PROTOCOL') AS protocolo,
       SYS_CONTEXT('USERENV','IP_ADDRESS')       AS ip_cliente
FROM dual;

PROMPT >>> PRB-14 [A.8.15] Eventos generados por estas pruebas
PROMPT     Esperado: SELECT/UPDATE sobre CLIENTES, LOGON fallidos (1017/28000),
PROMPT               ALTER USER del desbloqueo
COLUMN dbusername FORMAT A16
COLUMN action_name FORMAT A14
COLUMN object_name FORMAT A12
COLUMN unified_audit_policies FORMAT A28
SELECT TO_CHAR(event_timestamp,'HH24:MI:SS') AS hora, dbusername, action_name,
       object_name, return_code, unified_audit_policies
FROM   unified_audit_trail
WHERE  event_timestamp > SYSTIMESTAMP - INTERVAL '30' MINUTE
AND    dbusername IN ('U_ANALISTA','U_OPERADOR','U_DESARROLLADOR','SYS')
ORDER  BY event_timestamp;

PROMPT >>> PRB-07b [A.5.33] Auditor intenta borrar registros de auditoria
PROMPT     Esperado: error (ORA-01031 / ORA-01752 / ORA-46385) - registros inmutables
DELETE FROM unified_audit_trail WHERE ROWNUM = 1;

PROMPT >>> Fin de la bateria de pruebas
SPOOL OFF
DISCONNECT
