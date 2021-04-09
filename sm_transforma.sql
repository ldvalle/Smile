CREATE TABLE sm_transforma
(
   clave char(10) NOT NULL,
   cod_mac_numerico integer,
   cod_mac_alfa char(10),
   descripcion char(50),
   cod_smile char(20)
);

CREATE INDEX inx01sm_transforma ON sm_transforma(clave, cod_mac_numerico, cod_mac_alfa);

GRANT select ON sm_transforma TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf, ctousu;

GRANT insert ON sm_transforma TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf, ctousu;

GRANT delete ON sm_transforma TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf, ctousu;

GRANT update ON sm_transforma  TO
supercal, superfat, supersre, superpjp, supersbl,
supercri, "UCENTRO", batchsyn,pjp, ftejera, sbl,
gtricoci, sreyes, ssalve, pablop, aarrien, vdiaz,
ldvalle, vaz, corbacho, pmf, ctousu;

begin work;

insert into tabla (sucursal, nomtabla, codigo, descripcion, valor_alf, fecha_activacion )values(
'0000', 'PATH', 'SMIGEN', 'Path Generacion SMILE', '/fs/migracion/generacion/SMILE/', TODAY);

insert into tabla (sucursal, nomtabla, codigo, descripcion, valor_alf, fecha_activacion )values(
'0000', 'PATH', 'SMICPY', 'Path Final SMILE', '/fs/migracion/Extracciones/SMILE/', TODAY);

commit work;

