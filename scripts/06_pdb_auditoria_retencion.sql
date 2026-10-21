-- =====================================================================
-- 06_pdb_auditoria_retencion.sql
-- Controles: A.8.15 (registro / logging), A.5.33 (proteccion de registros),
--            A.8.12 (prevencion de fuga: auditoria de exportaciones)
-- Tareas   : T-07 Auditoria, T-11 Gestion y retencion de logs
-- Ejecutar : sqlplus / as sysdba   (cambia a XEPDB1)
--
-- Usa Unified Auditing (12.2+). En 21c XE la base trabaja en modo mixto;
-- las politicas unificadas funcionan igual y escriben en UNIFIED_AUDIT_TRAIL
-- (tablas del esquema AUDSYS, protegidas contra DML incluso para SYS).
-- =====================================================================
SET ECHO ON
SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 100

ALTER SESSION SET CONTAINER = XEPDB1;

-- 1. Acceso a datos confidenciales (lectura y modificacion)
CREATE AUDIT POLICY pol_aud_datos_conf
  ACTIONS SELECT ON app_conf.clientes,
          INSERT ON app_conf.clientes,
          UPDATE ON app_conf.clientes,
          DELETE ON app_conf.clientes;

-- 2. Cambios de seguridad (usuarios, privilegios, politicas)
CREATE AUDIT POLICY pol_aud_admin_conf
  PRIVILEGES CREATE USER, ALTER USER, DROP USER, CREATE ROLE,
             GRANT ANY PRIVILEGE, GRANT ANY ROLE, GRANT ANY OBJECT PRIVILEGE,
             ALTER SYSTEM
  ACTIONS GRANT, REVOKE, CREATE PROFILE, ALTER PROFILE, DROP PROFILE,
          EXECUTE ON SYS.DBMS_REDACT,
          EXECUTE ON SYS.DBMS_RLS;

-- 3. Exportaciones con Data Pump (vector de fuga de datos)
CREATE AUDIT POLICY pol_aud_exportaciones
  ACTIONS COMPONENT = DATAPUMP EXPORT;

AUDIT POLICY pol_aud_datos_conf;
AUDIT POLICY pol_aud_admin_conf;
AUDIT POLICY pol_aud_exportaciones;

-- 4. Politicas predefinidas de Oracle (pueden estar ya activas)
DECLARE
  PROCEDURE ej (p_sql VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE p_sql;
    DBMS_OUTPUT.PUT_LINE('OK       : ' || p_sql);
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('YA ACTIVA: ' || p_sql || ' -> ' || SQLERRM);
  END;
BEGIN
  ej('AUDIT POLICY ORA_LOGON_FAILURES WHENEVER NOT SUCCESSFUL');
  ej('AUDIT POLICY ORA_ACCOUNT_MGMT');
  ej('AUDIT POLICY ORA_SECURECONFIG');
END;
/

-- 5. Retencion de registros: 365 dias (A.5.33)
--    a) Marca de "archivado" = hoy - 365 dias
--    b) Job de purga diario que borra solo lo anterior a esa marca
--    c) Job que mueve la marca cada dia (ventana movil de 365 dias)
BEGIN
  DBMS_AUDIT_MGMT.SET_LAST_ARCHIVE_TIMESTAMP(
    audit_trail_type  => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
    last_archive_time => SYSTIMESTAMP - NUMTODSINTERVAL(365, 'DAY'));

  DBMS_AUDIT_MGMT.CREATE_PURGE_JOB(
    audit_trail_type           => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
    audit_trail_purge_interval => 24,
    audit_trail_purge_name     => 'PURGA_AUDIT_CONF',
    use_last_arch_timestamp    => TRUE);

  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'JOB_RETENCION_AUDIT_CONF',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'BEGIN DBMS_AUDIT_MGMT.SET_LAST_ARCHIVE_TIMESTAMP('
                       || 'DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED, '
                       || 'SYSTIMESTAMP - NUMTODSINTERVAL(365, ''DAY'')); END;',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY;BYHOUR=1',
    enabled         => TRUE,
    comments        => 'A.5.33 - Ventana movil de retencion de auditoria (365 dias)');
END;
/

-- Evidencias
COLUMN policy_name FORMAT A28
COLUMN entity_name FORMAT A12
SELECT policy_name, enabled_option, entity_name, success, failure
FROM   audit_unified_enabled_policies
ORDER  BY policy_name;

SELECT job_name, job_status, job_frequency FROM dba_audit_mgmt_cleanup_jobs;
SELECT audit_trail, last_archive_ts FROM dba_audit_mgmt_last_arch_ts;
SELECT parameter, value FROM v$option WHERE parameter = 'Unified Auditing';
