-- =====================================================================
-- 05_pdb_redaction_vpd.sql
-- Controles: A.8.11 (enmascaramiento de datos) con Oracle Data Redaction
--            A.8.3  (restriccion de acceso a la informacion) con VPD
-- Tarea DBA: T-05 Enmascaramiento / Redaction
-- Ejecutar : sqlplus / as sysdba   (cambia a XEPDB1)
--
-- NOTA: "Dynamic Data Masking" es el nombre en SQL Server. En Oracle el
-- equivalente es Data Redaction (paquete DBMS_REDACT).
-- SYS y quien tenga EXEMPT REDACTION POLICY ven los datos reales: las
-- pruebas deben hacerse conectado como U_ANALISTA (script 21).
-- =====================================================================
SET ECHO ON
SET SERVEROUTPUT ON
SET LINESIZE 200

ALTER SESSION SET CONTAINER = XEPDB1;

-- ---------------------------------------------------------------------
-- A. DATA REDACTION: se enmascara para todos los que NO tengan
--    activo el rol ROL_OPERADOR_CONF ni sean codigo del esquema APP_CONF.
-- ---------------------------------------------------------------------
BEGIN
  -- Cedula 901230456 -> *****0456  (parcial; la salida debe medir igual
  -- que la columna VARCHAR2(9), si no Oracle da ORA-28085)
  DBMS_REDACT.ADD_POLICY(
    object_schema       => 'APP_CONF',
    object_name         => 'CLIENTES',
    policy_name         => 'POL_REDACT_CLIENTES',
    column_name         => 'CEDULA',
    function_type       => DBMS_REDACT.PARTIAL,
    function_parameters => 'VVVVVVVVV,VVVVVVVVV,*,1,5',
    -- Excepciones: rol operador activo, o codigo del propio esquema dueno
    -- (procedimientos de APP_CONF, p. ej. la purga del script 07)
    expression          => 'SYS_CONTEXT(''SYS_SESSION_ROLES'',''ROL_OPERADOR_CONF'') = ''FALSE'''
                        || ' AND SYS_CONTEXT(''USERENV'',''CURRENT_USER'') <> ''APP_CONF''',
    policy_description  => 'A.8.11 - Enmascaramiento de datos personales (Ley 8968)');

  -- Salario -> 0  (total)
  DBMS_REDACT.ALTER_POLICY(
    object_schema => 'APP_CONF', object_name => 'CLIENTES',
    policy_name   => 'POL_REDACT_CLIENTES',
    action        => DBMS_REDACT.ADD_COLUMN,
    column_name   => 'SALARIO',
    function_type => DBMS_REDACT.FULL);

  -- Tarjeta 4111222233334444 -> ************4444  (parcial, VARCHAR2(16))
  DBMS_REDACT.ALTER_POLICY(
    object_schema       => 'APP_CONF', object_name => 'CLIENTES',
    policy_name         => 'POL_REDACT_CLIENTES',
    action              => DBMS_REDACT.ADD_COLUMN,
    column_name         => 'TARJETA',
    function_type       => DBMS_REDACT.PARTIAL,
    function_parameters => 'VVVVVVVVVVVVVVVV,VVVVVVVVVVVVVVVV,*,1,12');

  -- Telefono 88887777 -> ****7777  (parcial)
  DBMS_REDACT.ALTER_POLICY(
    object_schema       => 'APP_CONF', object_name => 'CLIENTES',
    policy_name         => 'POL_REDACT_CLIENTES',
    action              => DBMS_REDACT.ADD_COLUMN,
    column_name         => 'TELEFONO',
    function_type       => DBMS_REDACT.PARTIAL,
    function_parameters => 'VVVVVVVV,VVVVVVVV,*,1,4');

  -- Email nombre@correo.cr -> xxxx@correo.cr  (expresion regular)
  DBMS_REDACT.ALTER_POLICY(
    object_schema          => 'APP_CONF', object_name => 'CLIENTES',
    policy_name            => 'POL_REDACT_CLIENTES',
    action                 => DBMS_REDACT.ADD_COLUMN,
    column_name            => 'EMAIL',
    function_type          => DBMS_REDACT.REGEXP,
    regexp_pattern         => DBMS_REDACT.RE_PATTERN_EMAIL_ADDRESS,
    regexp_replace_string  => DBMS_REDACT.RE_REDACT_EMAIL_NAME,
    regexp_position        => DBMS_REDACT.RE_BEGINNING,
    regexp_occurrence      => DBMS_REDACT.RE_ALL);
END;
/

-- ---------------------------------------------------------------------
-- B. VIRTUAL PRIVATE DATABASE (VPD): el analista solo ve clientes de su
--    region asignada (HEREDIA). Filtra filas en SELECT/INSERT/UPDATE/DELETE.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app_conf.fn_vpd_clientes (
  p_schema IN VARCHAR2,
  p_objeto IN VARCHAR2
) RETURN VARCHAR2
AS
BEGIN
  IF SYS_CONTEXT('USERENV','SESSION_USER') = 'U_ANALISTA' THEN
    RETURN 'PROVINCIA = ''HEREDIA''';
  END IF;
  RETURN NULL;   -- sin restriccion para los demas roles autorizados
END;
/

BEGIN
  DBMS_RLS.ADD_POLICY(
    object_schema   => 'APP_CONF',
    object_name     => 'CLIENTES',
    policy_name     => 'POL_VPD_CLIENTES',
    function_schema => 'APP_CONF',
    policy_function => 'FN_VPD_CLIENTES',
    statement_types => 'SELECT,INSERT,UPDATE,DELETE',
    update_check    => TRUE,
    enable          => TRUE);
END;
/

-- Evidencias
COLUMN object_name FORMAT A12
COLUMN policy_name FORMAT A22
COLUMN column_name FORMAT A12
COLUMN function_parameters FORMAT A35
COLUMN expression FORMAT A60
SELECT object_owner, object_name, policy_name, expression, enable
FROM   redaction_policies;

SELECT object_name, column_name, function_type, function_parameters
FROM   redaction_columns
WHERE  object_owner = 'APP_CONF';

SELECT object_owner, object_name, policy_name, function, sel, ins, upd, del, enable
FROM   dba_policies
WHERE  object_owner = 'APP_CONF';
