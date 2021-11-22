
CREATE TABLE anomalias_cnr (
codigo1         char(4),
descripcion1    varchar(100),
codigo2         char(4),
descripcion2    varchar(100),
categoria       char(4),
precedencia     smallint,
genera_cnr      smallint,
genera_ot       smallint,
fecha_alta      date,
fecha_baja      date);

create index inxanomcnr1 on anomalias_cnr (codigo1, codigo2);

GRANT select ON anomalias_cnr  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf, ctousu, "UINSPECC";

GRANT insert ON anomalias_cnr  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf, ctousu, "UINSPECC";

GRANT delete ON anomalias_cnr  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf, ctousu, "UINSPECC";

GRANT update ON anomalias_cnr  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf, ctousu, "UINSPECC";

-----------------

CREATE TABLE ot_motivos_cnr (
codigo         char(4),
fecha_alta      date,
fecha_baja      date);

create index inxotmotcnr on ot_motivos_cnr (codigo);

GRANT select ON ot_motivos_cnr  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf, ctousu, "UINSPECC";

GRANT insert ON ot_motivos_cnr  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf, ctousu, "UINSPECC";

GRANT delete ON ot_motivos_cnr  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf, ctousu, "UINSPECC";

GRANT update ON ot_motivos_cnr  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf, ctousu, "UINSPECC";

BEGIN WORK;

INSERT INTO tabla (sucursal, nomtabla, codigo, descripcion, valor_alf, fecha_activacion
)VALUES('0000', 'PATH', 'SMIMAC', 'Path Intefaces SMILE MAC', '/fs/migracion/Extracciones/SMILE/SmileToMac/', TODAY);

COMMIT WORK;

ALTER TABLE cnr_new ADD (fecha_estado datetime year to second, fecha_desde_periodo date, fecha_hasta_periodo date, monto_facturado decimal(12,2), clase_tarifa smallint);

ALTER TABLE cnr_factura ADD (fecha_envio_sap date);


