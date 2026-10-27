# Controles para Riesgos de Confidencialidad — Tareas del administrador de Bases de Datos

**Universidad Nacional de Costa Rica · Escuela de Informática**
Curso: Administración de Bases de Datos · Prof. Johnny Villalobos Murillo · II Ciclo 2026
Estudiante: Jeimy Espinoza Barquero

Marco de controles basado en ISO/IEC 27001:2022 (Anexo A) e ISO/IEC 27002:2022 para mitigar riesgos de confidencialidad en las tareas del DBA. Se implementó y verificó en Oracle Database 21c Express Edition (CDB `XE`, PDB `XEPDB1`), siguiendo el ciclo PHVA.

## Contenido

| Carpeta / archivo | Qué contiene |
|---|---|
| `scripts/` | Scripts SQL y RMAN de implementación (01 a 10b), verificación (20), pruebas (21) y reversión (99). El orden de ejecución está en `scripts/LEEME.md` |
| `scripts/evidencia_pruebas.txt` | Salida de la batería de pruebas por usuario (script 21) |
| `scripts/evidencia_controles.txt` | Salida de la verificación de los 18 controles (script 20) |
| `scripts/evidencia_backup.log` | Bitácora de RMAN: respaldo cifrado AES256 y `RESTORE DATABASE VALIDATE` |
| `index.html` | Artefacto interactivo (publicado con GitHub Pages) |
| `informe/` | Informe en PDF con marco teórico, resultados, hallazgos, tabla de uso de IA y referencias APA 7 |

**Artefacto interactivo:** https://jeimye.github.io/controles-confidencialidad-dba/

**Video explicativo:** https://youtu.be/3mNyXkx-qyU

## Resumen de resultados

- 18 controles evaluados (15 del enunciado y 3 complementarios: A.8.8, A.8.24 y A.8.33).
- 16 cumplen y 2 quedan en estado parcial: A.8.12 (PUBLIC con paquetes `UTL_*`) y A.8.8 (XE sin parches).
- 25 pruebas definidas, 22 ejecutadas y conformes; PRB-03, PRB-19 y PRB-24 quedan pendientes.

## Nota sobre la evidencia de respaldo

Las últimas líneas de `scripts/evidencia_backup.log` muestran un error de sintaxis de RMAN (`RMAN-00558 … OFFSPOOL`). Se produjo al escribir dos veces el comando `SPOOL LOG OFF`, después de que el respaldo y la validación `RESTORE DATABASE VALIDATE` terminaron correctamente; no afecta al respaldo.

## Nota de seguridad

Los datos de la tabla `CLIENTES` son ficticios. Las contraseñas que aparecen en los scripts son de laboratorio: la instancia solo acepta conexiones desde el propio equipo (`TCP.INVITED_NODES`). Cámbielas antes de ejecutar los scripts en otro entorno.

## Uso de inteligencia artificial

Este trabajo se desarrolló con apoyo de Claude (Anthropic). El detalle de los prompts, los aportes de la IA y la validación de la estudiante está en la sección 8 del informe.
