-- =====================================================================
-- 99_rollback.sql
-- Deshace los scripts 02 a 08 para volver a ejecutarlos desde cero.
-- NO elimina el keystore TDE (script 01) ni desactiva ARCHIVELOG (10a):
-- borrar un keystore con datos cifrados los vuelve irrecuperables.
-- Ejecutar : sqlplus / as sysdba
-- =====================================================================
SET SERVEROUTPUT ON
SET LINESIZE 200

ALTER SESSION SET CONTAINER = XEPDB1;

DECLARE
  PROCEDURE ej (p_sql VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE p_sql;
    DBMS_OUTPUT.PUT_LINE('OK      : ' || SUBSTR(p_sql, 1, 90));
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('OMITIDO : ' || SUBSTR(p_sql, 1, 90) || ' -> ' || SQLERRM);
  END;
BEGIN
  -- Auditoria y retencion
  ej('NOAUDIT POLICY pol_aud_datos_conf');
  ej('NOAUDIT POLICY pol_aud_admin_conf');
  ej('NOAUDIT POLICY pol_aud_exportaciones');
  ej('DROP AUDIT POLICY pol_aud_datos_conf');
  ej('DROP AUDIT POLICY pol_aud_admin_conf');
  ej('DROP AUDIT POLICY pol_aud_exportaciones');
  ej('BEGIN DBMS_AUDIT_MGMT.DROP_PURGE_JOB(''PURGA_AUDIT_CONF''); END;');
  ej('BEGIN DBMS_AUDIT_MGMT.CLEAR_LAST_ARCHIVE_TIMESTAMP(DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED); END;');
  ej('BEGIN DBMS_SCHEDULER.DROP_JOB(''JOB_RETENCION_AUDIT_CONF''); END;');

  -- Redaction y VPD
  ej('BEGIN DBMS_REDACT.DROP_POLICY(''APP_CONF'',''CLIENTES'',''POL_REDACT_CLIENTES''); END;');
  ej('BEGIN DBMS_RLS.DROP_POLICY(''APP_CONF'',''CLIENTES'',''POL_VPD_CLIENTES''); END;');

  -- Usuarios, roles y perfil
  FOR u IN (SELECT username FROM dba_users
            WHERE username IN ('U_ANALISTA','U_OPERADOR','U_AUDITOR','U_DBA_JR',
                               'U_DESARROLLADOR','APP_CONF_DEV','APP_CONF')) LOOP
    ej('DROP USER ' || u.username || ' CASCADE');
  END LOOP;
  FOR r IN (SELECT role FROM dba_roles WHERE role LIKE 'ROL\_%\_CONF' ESCAPE '\') LOOP
    ej('DROP ROLE ' || r.role);
  END LOOP;
  ej('DROP PROFILE perfil_conf');

  -- Tablespace cifrado
  ej('DROP TABLESPACE ts_conf_enc INCLUDING CONTENTS AND DATAFILES');
  ej('PURGE DBA_RECYCLEBIN');
END;
/

-- Usuarios comunes (CDB)
ALTER SESSION SET CONTAINER = CDB$ROOT;
BEGIN
  FOR u IN (SELECT username FROM dba_users WHERE username IN ('C##BACKUP_OP','C##KEY_ADMIN')) LOOP
    EXECUTE IMMEDIATE 'DROP USER ' || u.username || ' CASCADE';
    DBMS_OUTPUT.PUT_LINE('OK      : DROP USER ' || u.username);
  END LOOP;
END;
/
