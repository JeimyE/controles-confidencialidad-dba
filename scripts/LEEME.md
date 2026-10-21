# Controles para Riesgos de Confidencialidad Tareas del administrador de Bases de Datos – Scripts (Oracle 21c XE)

Laboratorio: CDB `XE` con PDB `XEPDB1`, en Windows.
Herramientas: SQL*Plus (PowerShell), SQL Developer y RMAN.

## Orden de ejecución

| # | Archivo | Conexión | Controles | Tarea |
|---|---|---|---|---|
| 0 | `mkdir C:\oracle_wallet\XE\tde` | PowerShell (admin) | — | — |
| 1 | `01_cdb_tde_keystore.sql` | `sqlplus / as sysdba` (reinicia la BD) | A.8.24 | T-04 |
| 2 | `02_cdb_separacion_funciones.sql` | `sqlplus / as sysdba` | A.8.2 | T-02 |
| 3 | `03_pdb_esquema_clasificacion.sql` | `sqlplus / as sysdba` | A.5.12, A.8.24, A.5.16 | T-04, T-01 |
| 4 | `04_pdb_usuarios_roles_perfiles.sql` | `sqlplus / as sysdba` | A.5.15–A.5.18, A.8.2, A.8.5 | T-01, T-02, T-03 |
| 5 | `05_pdb_redaction_vpd.sql` | `sqlplus / as sysdba` | A.8.11, A.8.3 | T-05 |
| 6 | `06_pdb_auditoria_retencion.sql` | `sqlplus / as sysdba` | A.8.15, A.5.33, A.8.12 | T-07, T-11 |
| 7 | `07_pdb_eliminacion_segura.sql` | `sqlplus / as sysdba` | A.8.10 | T-10 |
| 8 | `08_pdb_entorno_dev_enmascarado.sql` | `sqlplus / as sysdba` | A.8.11, A.8.12, A.8.33 | T-12 |
| 9 | `09_red_sqlnet_ora.plantilla` | editar `sqlnet.ora` y luego `lsnrctl reload` | A.8.20, A.8.5 | T-09 |
| 10 | `10a_habilitar_archivelog.sql` | `sqlplus / as sysdba` (reinicia la BD) | A.8.13 | T-06 |
| 11 | `10b_backup_cifrado.rman` | `rman target / cmdfile=10b_backup_cifrado.rman log=evidencia_backup.log` | A.8.13, A.8.24 | T-06 |
| 12 | `21_pruebas_funcionales.sql` | `sqlplus /nolog @21_pruebas_funcionales.sql` | todos | — |
| 13 | `20_verificacion_controles.sql` | `sqlplus / as sysdba` o SQL Developer (F5) | los 15 + 3 | — |
| — | `99_rollback.sql` | `sqlplus / as sysdba` | — | — |

**Orden de las pruebas:** ejecute `21` antes que `20`. Así los eventos de las pruebas ya aparecen en la evidencia de auditoría (A.8.15).

**Si un script falla a la mitad:** ejecute `99_rollback.sql` y vuelva a empezar desde el `02`. El keystore del `01` se conserva.

## Evidencias que se generan

- `evidencia_controles.txt`: salida del script 20, para anexar al informe.
- `evidencia_pruebas.txt`: salida del script 21, con los resultados de la batería de pruebas.
- `evidencia_backup.log`: salida de RMAN.
- Capturas de pantalla de SQL Developer para el informe y el video.

## Notas del motor

- **TDE y Data Redaction sí están incluidos en 21c XE.** En 11g XE no lo estaban.
- **"Dynamic Data Masking" es el nombre en SQL Server.** En Oracle el equivalente es Data Redaction (`DBMS_REDACT`).
- **XE no trae el *Data Masking and Subsetting Pack*.** El enmascaramiento de DEV se hace con SQL propio (script 08).
- **XE no recibe Release Updates.** Por eso el control A.8.8 queda como hallazgo Parcial.
- **`pg_hba.conf` (del enunciado) es de PostgreSQL.** En Oracle el equivalente es `sqlnet.ora` (`TCP.VALIDNODE_CHECKING`, `TCP.INVITED_NODES`).
- **Las contraseñas de los scripts son de laboratorio.** Cámbielas en los `DEFINE` y no las suba al repositorio Git.
