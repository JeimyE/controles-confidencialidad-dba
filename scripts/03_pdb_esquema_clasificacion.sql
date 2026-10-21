-- =====================================================================
-- 03_pdb_esquema_clasificacion.sql
-- Controles: A.5.12 (clasificacion), A.8.24 (tablespace cifrado),
--            A.5.16 (cuenta de esquema sin autenticacion)
-- Tareas   : T-04 Cifrado TDE, T-01 Gestion de usuarios
-- Ejecutar : sqlplus / as sysdba   (cambia a XEPDB1)
-- Requiere : 01_cdb_tde_keystore.sql ejecutado (keystore abierto)
-- =====================================================================
SET ECHO ON
SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 100

ALTER SESSION SET CONTAINER = XEPDB1;

-- Ruta de datafiles de XEPDB1 (se calcula sola)
COLUMN ruta NEW_VALUE RUTA_DF NOPRINT
SELECT REGEXP_SUBSTR(file_name, '^.*[\\/]') AS ruta
FROM   dba_data_files
WHERE  tablespace_name = 'SYSTEM';

-- 1. Tablespace cifrado con TDE (AES256)
CREATE TABLESPACE ts_conf_enc
  DATAFILE '&RUTA_DF.TS_CONF_ENC01.DBF' SIZE 100M
  AUTOEXTEND ON NEXT 10M MAXSIZE 1G
  ENCRYPTION USING 'AES256' ENCRYPT;

-- 2. Esquema propietario SIN autenticacion (schema-only account):
--    nadie puede iniciar sesion como dueno de los datos.
CREATE USER app_conf NO AUTHENTICATION
  DEFAULT TABLESPACE ts_conf_enc
  QUOTA UNLIMITED ON ts_conf_enc;

-- 3. Tabla con datos personales (Ley 8968)
CREATE TABLE app_conf.clientes (
  id_cliente             NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cedula                 VARCHAR2(9)    NOT NULL,
  nombre                 VARCHAR2(100)  NOT NULL,
  email                  VARCHAR2(120),
  telefono               VARCHAR2(8),
  provincia              VARCHAR2(20)   NOT NULL,
  salario                NUMBER(12,2),
  tarjeta                VARCHAR2(16),
  fecha_ultima_actividad DATE DEFAULT SYSDATE,
  estado                 VARCHAR2(10) DEFAULT 'ACTIVO',
  CONSTRAINT uq_clientes_cedula UNIQUE (cedula)
) TABLESPACE ts_conf_enc;

-- 4. Catalogo de clasificacion de la informacion (A.5.12)
CREATE TABLE app_conf.catalogo_clasificacion (
  tabla             VARCHAR2(30),
  columna           VARCHAR2(30),
  nivel             VARCHAR2(15)
                    CHECK (nivel IN ('PUBLICO','INTERNO','CONFIDENCIAL','RESTRINGIDO')),
  categoria_dato    VARCHAR2(60),
  control_aplicado  VARCHAR2(80),
  CONSTRAINT pk_catalogo PRIMARY KEY (tabla, columna)
) TABLESPACE ts_conf_enc;

INSERT INTO app_conf.catalogo_clasificacion VALUES ('CLIENTES','ID_CLIENTE','INTERNO','Identificador tecnico','Control de acceso por rol');
INSERT INTO app_conf.catalogo_clasificacion VALUES ('CLIENTES','CEDULA','CONFIDENCIAL','Dato personal identificativo (Ley 8968)','Redaction parcial + TDE');
INSERT INTO app_conf.catalogo_clasificacion VALUES ('CLIENTES','NOMBRE','INTERNO','Dato personal identificativo (Ley 8968)','VPD + TDE');
INSERT INTO app_conf.catalogo_clasificacion VALUES ('CLIENTES','EMAIL','CONFIDENCIAL','Dato personal de contacto (Ley 8968)','Redaction regex + TDE');
INSERT INTO app_conf.catalogo_clasificacion VALUES ('CLIENTES','TELEFONO','CONFIDENCIAL','Dato personal de contacto (Ley 8968)','Redaction parcial + TDE');
INSERT INTO app_conf.catalogo_clasificacion VALUES ('CLIENTES','PROVINCIA','INTERNO','Dato de ubicacion general','Base del filtro VPD');
INSERT INTO app_conf.catalogo_clasificacion VALUES ('CLIENTES','SALARIO','RESTRINGIDO','Dato financiero (acceso restringido)','Redaction total + TDE');
INSERT INTO app_conf.catalogo_clasificacion VALUES ('CLIENTES','TARJETA','RESTRINGIDO','Dato financiero (acceso restringido)','Redaction parcial + TDE');
COMMIT;

-- Etiquetas en el diccionario de datos
COMMENT ON TABLE  app_conf.clientes          IS 'CLASIFICACION=CONFIDENCIAL | Contiene datos personales - Ley 8968';
COMMENT ON COLUMN app_conf.clientes.cedula   IS 'CLASIFICACION=CONFIDENCIAL | Dato personal identificativo';
COMMENT ON COLUMN app_conf.clientes.email    IS 'CLASIFICACION=CONFIDENCIAL | Dato personal de contacto';
COMMENT ON COLUMN app_conf.clientes.telefono IS 'CLASIFICACION=CONFIDENCIAL | Dato personal de contacto';
COMMENT ON COLUMN app_conf.clientes.salario  IS 'CLASIFICACION=RESTRINGIDO | Dato financiero';
COMMENT ON COLUMN app_conf.clientes.tarjeta  IS 'CLASIFICACION=RESTRINGIDO | Dato financiero';

-- 5. Datos de prueba (ficticios)
-- Registros fijos usados por las pruebas:
INSERT INTO app_conf.clientes (cedula, nombre, email, telefono, provincia, salario, tarjeta, fecha_ultima_actividad)
VALUES ('901230456','Zuleyka Prueba Confidencial','zuleyka.prueba@correo.cr','88887777','HEREDIA',1850000,'4111222233334444',SYSDATE);

INSERT INTO app_conf.clientes (cedula, nombre, email, telefono, provincia, salario, tarjeta, fecha_ultima_actividad)
VALUES ('305550111','Titular Supresion Solicitada','titular.supresion@correo.cr','87776666','CARTAGO',950000,'5500111122223333',SYSDATE);

INSERT INTO app_conf.clientes (cedula, nombre, email, telefono, provincia, salario, tarjeta, fecha_ultima_actividad)
VALUES ('206660222','Cliente Inactivo Antiguo','inactivo.antiguo@correo.cr','86665555','ALAJUELA',720000,'4000111122225555',ADD_MONTHS(SYSDATE,-84));

-- 60 registros generados
DECLARE
  TYPE t_lista IS VARRAY(8) OF VARCHAR2(20);
  v_prov t_lista := t_lista('SAN JOSE','ALAJUELA','CARTAGO','HEREDIA','GUANACASTE','PUNTARENAS','LIMON','HEREDIA');
  v_nom  t_lista := t_lista('Ana','Luis','Carlos','Sofia','Daniel','Valeria','Jose','Camila');
  v_ape  t_lista := t_lista('Mora','Vargas','Jimenez','Rojas','Chaves','Alfaro','Solis','Araya');
BEGIN
  FOR i IN 1 .. 60 LOOP
    INSERT INTO app_conf.clientes
      (cedula, nombre, email, telefono, provincia, salario, tarjeta, fecha_ultima_actividad)
    VALUES (
      TO_CHAR(100000000 + i * 1234567),
      v_nom(MOD(i,8)+1) || ' ' || v_ape(MOD(i*3,8)+1) || ' ' || v_ape(MOD(i*5,8)+1),
      'cliente' || i || '@correo.cr',
      '8' || LPAD(TO_CHAR(MOD(i*98765, 10000000)), 7, '0'),
      v_prov(MOD(i,8)+1),
      ROUND(DBMS_RANDOM.VALUE(450000, 3500000), 2),
      '4111' || LPAD(TO_CHAR(i*104729), 12, '0'),
      SYSDATE - TRUNC(DBMS_RANDOM.VALUE(0, 1500))
    );
  END LOOP;
  COMMIT;
END;
/

-- Evidencia
SELECT tablespace_name, encrypted FROM dba_tablespaces WHERE tablespace_name = 'TS_CONF_ENC';
SELECT username, authentication_type, account_status FROM dba_users WHERE username = 'APP_CONF';
SELECT COUNT(*) AS total_clientes FROM app_conf.clientes;
