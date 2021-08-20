
CREATE TABLE anomalias_cnr (
codigo1         char(4),
descripcion1    varchar(100),
codigo2         char(4),
descripcion2    varchar(100),
categoria       char(4),
precedencia     smallint,
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

