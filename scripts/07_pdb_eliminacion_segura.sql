-- =====================================================================
-- 07_pdb_eliminacion_segura.sql
-- Controles: A.8.10 (eliminacion de informacion), A.5.33
-- Tarea DBA: T-10 Eliminacion segura
-- Ejecutar : sqlplus / as sysdba   (cambia a XEPDB1)
--
-- Enfoque:
--  1. Derecho de supresion del titular (Ley 8968): procedimiento
--     controlado; el operador NO tiene DELETE directo.
--  2. Purga por retencion: clientes inactivos mas de N anios.
--  3. Trazabilidad sin reexponer el dato: se registra el HASH SHA-256
--     de la cedula, no la cedula.
--  4. Los bloques liberados quedan dentro de un tablespace cifrado con
--     TDE, por lo que el residuo fisico no es legible (borrado
--     criptografico parcial). Objetos eliminados con DROP ... PURGE.
-- =====================================================================
SET ECHO ON
SET SERVEROUTPUT ON
SET LINESIZE 200

ALTER SESSION SET CONTAINER = XEPDB1;

CREATE TABLE app_conf.registro_supresiones (
  id_registro    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  hash_cedula    RAW(32)       NOT NULL,
  tipo           VARCHAR2(20)  NOT NULL,   -- TITULAR | RETENCION
  motivo         VARCHAR2(200),
  ejecutado_por  VARCHAR2(128) NOT NULL,
  fecha          TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL
) TABLESPACE ts_conf_enc;

-- 1. Supresion a solicitud del titular
CREATE OR REPLACE PROCEDURE app_conf.prc_suprimir_titular (
  p_cedula IN VARCHAR2,
  p_motivo IN VARCHAR2
) AS
  v_filas NUMBER;
BEGIN
  DELETE FROM app_conf.clientes WHERE cedula = p_cedula;
  v_filas := SQL%ROWCOUNT;
  IF v_filas = 0 THEN
    RAISE_APPLICATION_ERROR(-20010, 'Titular no encontrado o fuera de su ambito');
  END IF;
  INSERT INTO app_conf.registro_supresiones (hash_cedula, tipo, motivo, ejecutado_por)
  VALUES (STANDARD_HASH(p_cedula, 'SHA256'), 'TITULAR', p_motivo,
          SYS_CONTEXT('USERENV','SESSION_USER'));
  COMMIT;
END;
/

-- 2. Purga por plazo de conservacion
CREATE OR REPLACE PROCEDURE app_conf.prc_purgar_inactivos (
  p_anios IN NUMBER DEFAULT 5
) AS
  v_total NUMBER := 0;
BEGIN
  FOR r IN (SELECT id_cliente, cedula
            FROM   app_conf.clientes
            WHERE  fecha_ultima_actividad < ADD_MONTHS(SYSDATE, -12 * p_anios))
  LOOP
    INSERT INTO app_conf.registro_supresiones (hash_cedula, tipo, motivo, ejecutado_por)
    VALUES (STANDARD_HASH(r.cedula, 'SHA256'), 'RETENCION',
            'Inactivo mas de ' || p_anios || ' anios',
            SYS_CONTEXT('USERENV','SESSION_USER'));
    DELETE FROM app_conf.clientes WHERE id_cliente = r.id_cliente;
    v_total := v_total + 1;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Registros purgados: ' || v_total);
END;
/

GRANT EXECUTE ON app_conf.prc_suprimir_titular TO rol_operador_conf;
GRANT SELECT  ON app_conf.registro_supresiones TO rol_auditor_conf;

-- Ejecutar la purga por retencion (elimina "Cliente Inactivo Antiguo")
EXEC app_conf.prc_purgar_inactivos(5);

-- 3. Papelera de reciclaje: no deben quedar copias de objetos borrados
PURGE DBA_RECYCLEBIN;

-- Evidencias
SELECT tipo, motivo, ejecutado_por, fecha, RAWTOHEX(hash_cedula) AS hash_sha256
FROM   app_conf.registro_supresiones;
SELECT COUNT(*) AS objetos_en_papelera FROM dba_recyclebin WHERE owner = 'APP_CONF';
SELECT tablespace_name, encrypted FROM dba_tablespaces WHERE tablespace_name = 'TS_CONF_ENC';
