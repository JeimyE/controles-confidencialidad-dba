-- =====================================================================
-- 08_pdb_entorno_dev_enmascarado.sql
-- Controles: A.8.11 (enmascaramiento), A.8.12 (prevencion de fuga),
--            A.8.33 (informacion de prueba) [complementario]
-- Tarea DBA: T-12 Clones DEV/TEST
-- Ejecutar : sqlplus / as sysdba   (cambia a XEPDB1)
--
-- XE no incluye el "Data Masking and Subsetting Pack" (es de Enterprise
-- Manager), por eso el enmascaramiento estatico se hace con SQL propio.
-- Se conserva la estructura y la distribucion (provincia, rango de
-- salario, fechas) pero ningun dato identifica a una persona real.
-- =====================================================================
SET ECHO ON
SET SERVEROUTPUT ON
SET LINESIZE 200

DEFINE PWD_DEV = 'Dv3#Hx7$Lp2026'

ALTER SESSION SET CONTAINER = XEPDB1;

-- 1. Esquema DEV separado (sin autenticacion) y desarrollador sin acceso a PROD
CREATE USER app_conf_dev NO AUTHENTICATION
  DEFAULT TABLESPACE users QUOTA 50M ON users;

CREATE USER u_desarrollador IDENTIFIED BY "&PWD_DEV" PROFILE perfil_conf;
CREATE ROLE rol_desarrollo_conf;

-- 2. Copia enmascarada (enmascaramiento estatico e irreversible)
CREATE TABLE app_conf_dev.clientes TABLESPACE users AS
SELECT id_cliente,
       '0' || LPAD(TO_CHAR(ROWNUM), 8, '0')               AS cedula,
       'Cliente Prueba ' || ROWNUM                         AS nombre,
       'cliente' || ROWNUM || '@ejemplo.test'              AS email,
       '2' || LPAD(TO_CHAR(ROWNUM), 7, '0')                AS telefono,
       provincia,
       ROUND(salario * DBMS_RANDOM.VALUE(0.85, 1.15), -3)  AS salario,
       '0000' || LPAD(TO_CHAR(ROWNUM), 12, '0')            AS tarjeta,
       fecha_ultima_actividad,
       estado
FROM   app_conf.clientes;

COMMENT ON TABLE app_conf_dev.clientes IS
  'CLASIFICACION=INTERNO | Copia DEV con datos sinteticos - generada por 08_pdb_entorno_dev_enmascarado.sql';

GRANT CREATE SESSION TO rol_desarrollo_conf;
GRANT SELECT, INSERT, UPDATE, DELETE ON app_conf_dev.clientes TO rol_desarrollo_conf;
GRANT rol_desarrollo_conf TO u_desarrollador;

-- 3. Evidencia: coincidencias de datos reales en DEV (esperado: 0 en todo)
SELECT
  (SELECT COUNT(*) FROM app_conf_dev.clientes d JOIN app_conf.clientes p ON d.cedula  = p.cedula)  AS cedulas_reales,
  (SELECT COUNT(*) FROM app_conf_dev.clientes d JOIN app_conf.clientes p ON d.nombre  = p.nombre)  AS nombres_reales,
  (SELECT COUNT(*) FROM app_conf_dev.clientes d JOIN app_conf.clientes p ON d.email   = p.email)   AS emails_reales,
  (SELECT COUNT(*) FROM app_conf_dev.clientes d JOIN app_conf.clientes p ON d.tarjeta = p.tarjeta) AS tarjetas_reales
FROM dual;

-- El desarrollador no tiene ningun privilegio sobre APP_CONF (esperado: 0)
SELECT COUNT(*) AS privilegios_dev_en_prod
FROM   dba_tab_privs
WHERE  owner = 'APP_CONF'
AND    grantee IN ('U_DESARROLLADOR','ROL_DESARROLLO_CONF');

-- Opcional: exportar DEV con Data Pump cifrado (queda auditado por
-- POL_AUD_EXPORTACIONES). Desde PowerShell:
--   expdp system@localhost:1521/XEPDB1 schemas=APP_CONF_DEV `
--         directory=DATA_PUMP_DIR dumpfile=dev_conf.dmp `
--         encryption=ALL encryption_mode=TRANSPARENT
--   (pide la contrasena de SYSTEM; luego revisar el evento en
--    UNIFIED_AUDIT_TRAIL con AUDIT_TYPE = 'Datapump')
