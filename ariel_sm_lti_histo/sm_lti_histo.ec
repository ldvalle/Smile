/*********************************************************************************
		
**********************************************************************************/
#include <locale.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sm_lti_histo.h";

/* Variables Globales */
$long	glNroCliente;
$int	giEstadoCliente;
$char	gsTipoGenera[2];
int   giTipoCorrida;
$long glFechaDesde;

FILE  	*fpUnx;
char	sArchivoUnx[100];
char	sSoloArchivoUnx[100];

char	sArchivoUnx2[100];

char	sPathSalida[100];
char	sPathCopia[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];
long	lCorrelativo;

long	cantProcesada;
long 	cantPreexistente;

char	sMensMail[1024];	

/* Variables Globales Host */
$long	lFechaLimiteInferior;
$int	iCorrelativos;

$dtime_t    gtInicioCorrida;
$char       sLstParametros[100];
$long       glFechaParametro;
$int 	iPlan;

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
int		iFlagMigra=0;
$long    lFechaRti;

char	*vSucursal[]={"0003", "0004", "0010", "0020", "0023", "0026", "0050", "0065", "0053", "0056", "0059", "0069"};
$char	sSucursal[5];
int		i;
$ClsCliente       regCliente;
$ClsFactura       regFactu;
$ClsAhorroHist    regAhorro;
$ClsFacts         regFact;


int         iFlagRefacturada;
$long       lFechaInicio;
$long       lFechaLecturaPrima;
$long       lFechaLectuAnterior;
long        lContador;
int         iIndice;

char        sFechaDesde[11];
char        sFechaHasta[11];
$long       lFechaDesde;
$long       lFechaHasta;

$long       cantConsu;
$long       cantLectuActi;
double      lectuDesdeAux;
double      lectuHastaAux;

int      iIndexFile=1;
int      iFilasFile;

	if(! AnalizarParametros(argc, argv)){
		exit(0);
	}

   setlocale(LC_ALL, "en_US.UTF-8");
   
	hora = time(&hora);
	
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));
	
	strcpy(nombreBase, argv[1]);
	
	$DATABASE :nombreBase;	
	
	$SET LOCK MODE TO WAIT 120;
	$SET ISOLATION TO DIRTY READ;
	/*$SET ISOLATION TO CURSOR STABILITY;*/
	
	CreaPrepare();

	strcpy(sFechaHasta, "31/08/2021");
	rdefmtdate(&lFechaHasta, "dd/mm/yyyy", sFechaHasta); 
	
	$EXECUTE selFechaLimInf into :lFechaLimiteInferior;
   
   $EXECUTE selFechaRti INTO :lFechaRti;
   
   if(SQLCODE != 0){
      printf("No se logró recuperar fecha RTI\n");
      exit(2);
   }
            
	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
   dtcurrent(&gtInicioCorrida);
   
	cantProcesada=0;
	cantPreexistente=0;

	/*********************************************
				AREA CURSOR PPAL
	**********************************************/
      
      lContador=0;
      iIndice=1;
      iFilasFile=0;
      
		if(!AbreArchivos(iIndexFile)){
			exit(1);	
		}
		
		$OPEN curClientes
		 USING	:iPlan;

      while(LeoCliente(&regCliente))
      {
		 iCantFact = 0; 
         cantConsu=0;
         cantLectuActi=0;
            
            if(regCliente.corr_facturacion > 0){
               lFechaLecturaPrima=0;
               lFechaLectuAnterior=0;

               if(glFechaParametro > 0)
                  lFechaInicio = glFechaParametro;
                  
               $OPEN curFactura USING  :regCliente.numero_cliente, :lFechaHasta;
               
/*                  
               $OPEN curFactura 
				USING  :regCliente.numero_cliente,
					   :regCliente.numero_cliente;
*/ 
					  

               while(LeoFactura(&regFactu))
				{

                  if(regFactu.indica_refact[0]=='N'){
                     if(regFactu.tipo_medidor[0]=='R' && strcmp(regFactu.sSucursal, "ESFP") != 0 ){

                        if(!getLectuReactiva(&regFactu)){
                           printf("No se encontró lecturas reactiva para cliente %ld correlativo %d\n", regFactu.numero_cliente, regFactu.corr_facturacion);
                        }

                     }
                     /* Generar Plano*/
if (iCantFact > 13)
printf("\n1 - %d", regCliente.numero_cliente);

					 tVecFacturas[iCantFact] = regFactu; 
					 iCantFact++;
/*
                     GenerarPlanos(fpUnx, regCliente, regFactu);
*/
                     iFilasFile++;

                  }else{

                     lectuDesdeAux=regFactu.lecturaActivaBase;
                     lectuHastaAux=regFactu.lecturaActivaCierre;
                     if(!getLectuActivaRefac(&regFactu)){

                        regFactu.lecturaActivaBase=lectuDesdeAux;
                        regFactu.lecturaActivaCierre=lectuHastaAux;
                 /*   printf("No se encontró lecturas activas refacturadas para cliente %ld correlativo %d\n", regFactu.numero_cliente, regFactu.corr_facturacion);                     */
                     }

                     if(regFactu.tipo_medidor[0]=='R' && strcmp(regFactu.sSucursal, "ESFP") != 0 ){

                        lectuDesdeAux=regFactu.lecturaReactivaBase;
                        lectuHastaAux=regFactu.lecturaReactivaCierre;

                        if(!getLectuReactivaRefac(&regFactu)){

                           regFactu.lecturaReactivaBase=lectuDesdeAux;
                           regFactu.lecturaReactivaCierre=lectuHastaAux;

                      /*     printf("No se encontró lecturas reactivas refacturadas para cliente %ld correlativo %d\n", regFactu.numero_cliente, regFactu.corr_facturacion);                        */
                        }
                     }
                     /* Generar Plano */
if (iCantFact > 13)
printf("\n2 - %d", regCliente.numero_cliente);

                     tVecFacturas[iCantFact] = regFactu;
                     iCantFact++;
/*
                     GenerarPlanos(fpUnx, regCliente, regFactu);
*/
                     iFilasFile++;
                  }
               }
               
               $CLOSE curFactura;
            }
            cantProcesada++;

         if(iFilasFile > 2000000){ /* para que no entre mas por aca */
            CerrarArchivos();
            MueveArchivos();
            iIndexFile++;
      		if(!AbreArchivos(iIndexFile)){
      			exit(1);	
      		}
            printf("Clientes Procesados hasta el momento: %ld\n", cantProcesada);            
            iFilasFile=0;
         }

		ImprimirTLIs(regCliente);
      } /* Clientes */
   
      $CLOSE curClientes;

      CerrarArchivos();

	$CLOSE DATABASE;

	$DISCONNECT CURRENT;

	/* ********************************************
				FIN AREA DE PROCESO
	********************************************* */
   
   MueveArchivos();

	printf("==============================================\n");
	printf("LTI-HISTORICO\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Clientes Procesados :       %ld \n",cantProcesada);
	printf("Clientes Preexistentes :    %ld \n",cantPreexistente);
	printf("==============================================\n");
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));						

	hora = time(&hora);
	printf("\nHora de finalizacion del proceso : %s\n", ctime(&hora));

	printf("Fin del proceso OK\n");	

	exit(0);
}	

short AnalizarParametros(argc, argv)
int		argc;
char	* argv[];
{
char  sFechaPar[11];
   
   memset(sFechaPar, '\0', sizeof(sFechaPar));
   memset(sLstParametros, '\0', sizeof(sLstParametros));
   
	if(argc < 6 || argc > 7){
		MensajeParametros();
		return 0;
	}
	
	memset(gsTipoGenera, '\0', sizeof(gsTipoGenera));
   
	if(strcmp(argv[2], "0")!=0 && strcmp(argv[2], "1")!=0 && strcmp(argv[2], "2")!=0){
		MensajeParametros();
		return 0;	
	}
	
	giEstadoCliente=atoi(argv[2]);
	
	strcpy(gsTipoGenera, argv[3]);
	
   giTipoCorrida=atoi(argv[4]);

   sprintf(sLstParametros, "%s %s %s %s", argv[1], argv[2], argv[3], argv[4]);

	iPlan = atoi(argv[5]);
   
	if(argc ==7){
      strcpy(sFechaPar, argv[6]);
      rdefmtdate(&glFechaParametro, "dd/mm/yyyy", sFechaPar); /*char to long*/
      sprintf(sLstParametros, " %s %s",sLstParametros , argv[5]);
	}else{
		glFechaParametro=-1;
	}
	
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("	<Base> = synergia.\n");
		printf("	<Estado Cliente> 0=Activos, 1=No Activos, 2=Ambos\n");
		printf("	<Tipo Generación> G = Generación, R = Regeneración.\n");
		printf("	<Tipo Corrida> 0=Normal, 1=Reducida\n");
	    printf("	<Plan>\n");
		printf("	<Fecha Inicio> = dd/mm/aaaa (opcional).\n");
}

short AbreArchivos(iFile)
int   iFile;
{
	
	memset(sArchivoUnx,'\0',sizeof(sArchivoUnx));
	memset(sSoloArchivoUnx,'\0',sizeof(sSoloArchivoUnx));
   memset(sArchivoUnx2,'\0',sizeof(sArchivoUnx2));
   
   FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));
	memset(sPathCopia,'\0',sizeof(sPathCopia));   

	strcpy(sPathSalida, RutaArchivos( sPathSalida, "SMIGEN" ));
	alltrim(sPathSalida,' ');

	strcpy(sPathCopia, RutaArchivos( sPathCopia, "SMICPY" ));
	alltrim(sPathCopia,' ');
   strcat(sPathCopia, "TLI/");

   
	sprintf( sArchivoUnx  , "%slectu_grupo_%d.txt", sPathSalida, iPlan);
	strcpy( sSoloArchivoUnx, "T1_lti_histo.unx");
   sprintf( sArchivoUnx2  , "%slectu_grupo_%s_%d.txt", sPathCopia, FechaGeneracion, iPlan );
   
	fpUnx=fopen( sArchivoUnx, "w" );
	if( !fpUnx ){
		printf("ERROR al abrir archivo %s.\n", fpUnx );
		return 0;
	}
	
	return 1;	
}

void CerrarArchivos(void)
{
	fclose(fpUnx);

}

void  MueveArchivos()
{
char	sCommand[1000];
int	iRcv;
char	sPathCp[100];

	memset(sCommand, '\0', sizeof(sCommand));
	memset(sPathCp, '\0', sizeof(sPathCp));
/*
   sprintf(sCommand, "iconv -f windows-1252 -t UTF-8 %s > %s ", sArchivoUnx, sArchivoUnx2);
   iRcv=system(sCommand);
*/

	sprintf(sCommand, "chmod 755 %s", sArchivoUnx);
	iRcv=system(sCommand);

	sprintf(sCommand, "mv %s %s", sArchivoUnx, sArchivoUnx2);
	iRcv=system(sCommand);		

}

void FormateaArchivos(sSucur, indice)
char  sSucur[5];
int   indice;
{
char	sCommand[1000];
int	iRcv, i;
char	sPathCp[100];


	memset(sCommand, '\0', sizeof(sCommand));
	memset(sPathCp, '\0', sizeof(sPathCp));

	if(giEstadoCliente==0){
		/*strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Activos/");*/
      sprintf(sPathCp, "%sActivos/", sPathCopia);
	}else{
		/*strcpy(sPathCp, "/fs/migracion/Extracciones/ISU/Generaciones/T1/Inactivos/");*/
      sprintf(sPathCp, "%sInactivos/", sPathCopia);
	}

	sprintf(sCommand, "chmod 755 %s", sArchivoUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchivoUnx, sPathCp);
	iRcv=system(sCommand);		

   if(iRcv == 0){
      sprintf(sCommand, "rm %s", sArchivoUnx);
      iRcv=system(sCommand);
   }
}

void CreaPrepare(void){
$char sql[10000];
$char sAux[1000];

	memset(sql, '\0', sizeof(sql));
	memset(sAux, '\0', sizeof(sAux));
	
	/******** Fecha Actual Formateada ****************/
	strcpy(sql, "SELECT TO_CHAR(TODAY, '%Y%m%d') FROM dual ");
	
	$PREPARE selFechaActualFmt FROM $sql;

	/******** Fecha Actual  ****************/
	strcpy(sql, "SELECT TO_CHAR(TODAY, '%d/%m/%Y') FROM dual ");
	
	$PREPARE selFechaActual FROM $sql;	

   /********* Fecha RTi **********/
	strcpy(sql, "SELECT fecha_modificacion ");
	strcat(sql, "FROM tabla ");
	strcat(sql, "WHERE nomtabla = 'SAPFAC' ");
	strcat(sql, "AND sucursal = '0000' "); 
	strcat(sql, "AND codigo = 'RTI-1' ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND (fecha_desactivac IS NULL OR fecha_desactivac > TODAY) ");
   
   $PREPARE selFechaRti FROM $sql;

	/******** Cursor CLIENTES  ****************/
	strcpy(sql, "SELECT c.numero_cliente, ");
   strcat(sql, "NVL(c.corr_facturacion, 0), ");
   strcat(sql, "TRIM(t2.acronimo_sap) tipo_tarifa, ");
   strcat(sql, "c.correlativo_ruta, ");
   strcat(sql, "REPLACE(c.obs_dir, '|', '-') obs_dir ");             /* strcat(sql, "c.info_adic_lectura ");  */
   strcat(sql, "FROM cliente c, sucur_centro_op sc, OUTER sap_transforma t1, OUTER sap_transforma t2 ");

   if(giTipoCorrida==1) 	
      strcat(sql, ", migra_activos ma ");
	
	if(giEstadoCliente==0){
		strcat(sql, "WHERE c.estado_cliente = 0 ");
	}else{
		strcat(sql, ", sap_inactivos si ");
		strcat(sql, "WHERE c.estado_cliente != 0 ");
	}

	strcat(sql, " AND c.sector   = ?	 ");

	if(glNroCliente > 0 ){
		strcat(sql, "AND c.numero_cliente = ? ");
	}

	strcat(sql, "AND c.tipo_sum NOT IN (5, 6) ");
	strcat(sql, "AND c.sector != 88 ");
   strcat(sql, "AND sc.cod_centro_op = c.sucursal ");
   strcat(sql, "AND t1.clave = 'TIPCLI' ");
   strcat(sql, "AND t1.cod_mac = c.tipo_cliente ");
   strcat(sql, "AND t2.clave = 'TARIFTYP' ");
   strcat(sql, "AND t2.cod_mac = c.tarifa ");

	if(giEstadoCliente!=0){
		strcat(sql, "AND si.numero_cliente = c.numero_cliente ");
	}
		
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cm.fecha_activacion < TODAY ");
	strcat(sql, "AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");	

   if(giTipoCorrida == 1)
      strcat(sql, "AND ma.numero_cliente = c.numero_cliente ");

	$PREPARE selClientes FROM $sql;
	
	$DECLARE curClientes CURSOR WITH HOLD FOR selClientes;

   /*********** Facturas ************/
   $PREPARE selFactura FROM "SELECT DISTINCT h.numero_cliente,  
		h.corr_facturacion, 
		l1.lectura_facturac - l2.lectura_facturac,  
		h.tarifa,  
		h.indica_refact, 
		l2.fecha_lectura  fdesde,  
		l1.fecha_lectura fhasta, 
		(l1.fecha_lectura - (l2.fecha_lectura + 1)) difdias, 
		((l1.lectura_facturac - l2.lectura_facturac)/ (l1.fecha_lectura - (l2.fecha_lectura + 1))) * 61 cons_61, 
		h.fecha_facturacion, 
		h.numero_factura, 
		l1.tipo_lectura, 
		'000T1'|| lpad(h.sector,2,0) || sc.cod_ul_sap porcion, 
		TRIM(sc.cod_ul_sap || lpad(h.sector , 2, 0) ||  lpad(h.zona,5,0)) unidad_lectura, 
		h.coseno_phi/100, 
		l2.corr_facturacion, 
		h.sector, 
		LPAD(h.zona, 5, 0), 
		l1.numero_medidor, 
		l1.marca_medidor, 
		l1.constante, 
		l1.lectura_facturac, 
		l2.lectura_facturac, 
		sc.cod_ul_sap, 
		h.consumo_sum, h.sucursal, -1, -1 
		FROM hisfac h, sap_regi_cliente rc , hislec l1, hislec l2, sucur_centro_op sc
		WHERE h.numero_cliente = ?
		AND h.numero_cliente  = rc.numero_cliente  
		AND (h.fecha_lectura   > rc.fecha_move_in  AND h.fecha_lectura <= ?)
		AND h.tipo_docto IN ('01', '07', '05', '11') 
		AND l1.numero_cliente = h.numero_cliente 
		AND l1.corr_facturacion = h.corr_facturacion 
		AND l1.tipo_lectura IN (1,2,3,4,7) 
		AND l2.numero_cliente = h.numero_cliente 
		AND l2.corr_facturacion = (SELECT MAX(l3.corr_facturacion) FROM hislec l3 
			WHERE l3.numero_cliente = h.numero_cliente 
			AND l3.corr_facturacion < h.corr_facturacion 
			AND l3.tipo_lectura IN (1,2,3,4,7)) 
		AND l2.tipo_lectura IN (1,2,3,4,7)
		AND sc.cod_centro_op = h.sucursal 
		ORDER BY 2  ASC ";
		
		
/*		
		UNION
		SELECT DISTINCT h.numero_cliente, 
		h.corr_facturacion + 1, 
		cons_activa_p1 + cons_activa_p2, 
		h.tarifa, 
		'N'  indica_refact, 
		h.fecha_lectura_ant  fdesde, 
		NVL(h.fecha_lectura_ver, h.fecha_lectura)  fhasta, 
		NVL(h.fecha_lectura_ver, h.fecha_lectura) -  h.fecha_lectura_ant - 1  difdias, 
		((cons_activa_p1 + cons_activa_p2) / (NVL(h.fecha_lectura_ver, h.fecha_lectura) -  h.fecha_lectura_ant - 1)) * 61 cons_61 , 
		NVL(fecha_gen_lec_r, (SELECT l.fecha_generacion    
			FROM agenda l, f1d_age_relacion f, agenda v 
			WHERE v.sucursal  =  h.sucursal    
			AND v.sector    =  h.sector      
			AND v.fecha_generacion = h.fecha_gen_ver_r  
			AND v.identif_agenda   = f.age_verificacion  
			AND l.identif_agenda    = f.age_lectura))    fecha_generacion,
		-1   numero_factura, 
		h.tipo_lectura, 
		'000T1'|| lpad(h.sector,2,0) || sc.cod_ul_sap porcion, 
		TRIM(sc.cod_ul_sap || lpad(h.sector , 2, 0) ||  lpad(h.zona,5,0)) unidad_lectura, 
		h.coseno_phi/100, 
		h.corr_facturacion, 
		h.sector, 
		LPAD(h.zona, 5, 0), 
		h.numero_medidor, 
		h.marca_medidor, 
		h.constante, 
		h.lectura_ant, 
		CASE WHEN (lectura_ant + (cons_activa_p1 + cons_activa_p1)/h.constante) >= POW(10, h.enteros) THEN   
		   (lectura_ant + (cons_activa_p1 + cons_activa_p2)/h.constante) - POW(10, h.enteros) 
		ELSE lectura_ant + (cons_activa_p1 + cons_activa_p2)/h.constante END, 
		sc.cod_ul_sap, 
		-1 consumo_sum, 'ESFP' flag_fp, 
		NVL(cons_reac_p1, 0) + NVL(cons_reac_p2, 0), 
		lectura_ant_reac 
		FROM fp_lectu h, cliente c, sucur_centro_op sc
		WHERE h.numero_cliente   = ?  
		AND h.numero_cliente   = c.numero_cliente 
		AND (h.corr_facturacion = c.corr_facturacion - 1 OR h.corr_fact_ant = c.corr_facturacion -1 )
		AND sc.cod_centro_op = h.sucursal
		and NVL(H.fecha_lectura_ver, H.fecha_lectura) > ( select distinct case when a.tipo_lectura = 8 then a.fecha_lectura else NULL end end from hislec a 
		where a.numero_cliente = h.numero_cliente and a.fecha_lectura = (select max(b.fecha_lectura) end from hislec b where b.numero_cliente = a.numero_cliente and b.tipo_lectura not in (5,6,7)) )
		ORDER BY 2  ASC ";
*/
   $DECLARE curFactura CURSOR WITH HOLD FOR selFactura;

   /************ Consumos Activa Refacturados ************/
   strcpy(sql, "SELECT kwh_refacturados, kvar_refac_reac "); 
   strcat(sql, "FROM refac ");
   strcat(sql, "WHERE numero_cliente = ? ");
   strcat(sql, "AND nro_docto_afect = ? ");
   strcat(sql, "AND fecha_fact_afect = ? ");

   $PREPARE selRefac FROM $sql;

   $DECLARE curRefac CURSOR WITH HOLD FOR selRefac;
   
   /********** Ahorro_Hist ************/
   strcpy(sql, "SELECT a1.numero_cliente, ");
   strcat(sql, "a1.corr_fact_act, ");
   strcat(sql, "a1.fecha_lectura_act_2 + 1, ");
   strcat(sql, "TO_CHAR(a1.fecha_lectura_act_2 + 1, '%Y%m%d'), ");
   strcat(sql, "a1.fecha_lectura_act, ");
   strcat(sql, "TO_CHAR(a1.fecha_lectura_act, '%Y%m%d'), ");
   strcat(sql, "a1.consumo_61dias_act, ");
   strcat(sql, "a1.dias_per_act ");
   strcat(sql, "FROM ahorro_hist a1 ");
   strcat(sql, "WHERE a1.numero_cliente = ? ");
   strcat(sql, "ORDER BY corr_fact_act ASC ");
   
   $PREPARE selAhorro FROM $sql;

   $DECLARE curAhorro CURSOR WITH HOLD FOR selAhorro;

   /************* Primera Lectura *****************/
	strcpy(sql, "SELECT MIN(h1.fecha_lectura) ");
	strcat(sql, "FROM hislec h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.tipo_lectura IN (1,2,3,4,7) ");   
   
   $PREPARE selPrimaLectura FROM $sql;

	/******** Select Path de Archivos ****************/
	strcpy(sql, "SELECT valor_alf ");
	strcat(sql, "FROM tabla ");
	strcat(sql, "WHERE nomtabla = 'PATH' ");
	strcat(sql, "AND codigo = ? ");
	strcat(sql, "AND sucursal = '0000' ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND ( fecha_desactivac >= TODAY OR fecha_desactivac IS NULL ) ");

	$PREPARE selRutaPlanos FROM $sql;

	/******** Select Correlativo ****************/
	strcpy(sql, "SELECT correlativo +1 FROM sap_gen_archivos ");
	strcat(sql, "WHERE sistema = 'SAPISU' ");
	strcat(sql, "AND tipo_archivo = ? ");
	
	/*$PREPARE selCorrelativo FROM $sql;*/

	/******** Update Correlativo ****************/
	strcpy(sql, "UPDATE sap_gen_archivos SET ");
	strcat(sql, "correlativo = correlativo + 1 ");
	strcat(sql, "WHERE sistema = 'SAPISU' ");
	strcat(sql, "AND tipo_archivo = ? ");
	
	/*$PREPARE updGenArchivos FROM $sql;*/
		
	/******** Insert gen_archivos ****************/
	strcpy(sql, "INSERT INTO sap_regiextra ( ");
	strcat(sql, "estructura, ");
	strcat(sql, "fecha_corrida, ");
	strcat(sql, "modo_corrida, ");
	strcat(sql, "cant_registros, ");
	strcat(sql, "numero_cliente, ");
	strcat(sql, "nombre_archivo ");
	strcat(sql, ")VALUES( ");
	strcat(sql, "'FACTSBIM', ");
	strcat(sql, "CURRENT, ");
	strcat(sql, "?, ?, ?, ?) ");
	
	/*$PREPARE insGenInstal FROM $sql;*/

	/********* Select Cliente ya migrado **********/
	strcpy(sql, "SELECT facts_bim, fecha_pivote FROM sap_regi_cliente ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE selClienteMigrado FROM $sql;

	/*********Insert Clientes extraidos **********/
	strcpy(sql, "INSERT INTO sap_regi_cliente ( ");
	strcat(sql, "numero_cliente, facts_bim, qconsbimes, facdiaspc, qconbfpact ");
	strcat(sql, ")VALUES(?, 'S', ?, ?, ?) ");
	
	$PREPARE insClientesMigra FROM $sql;
	
	/************ Update Clientes Migra **************/
	strcpy(sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "facts_bim = 'S', ");
	strcat(sql, "qconsbimes = ?, ");
	strcat(sql, "facdiaspc = ?, ");
	strcat(sql, "qconbfpact = ? ");
	strcat(sql, "WHERE numero_cliente = ? ");
	
	$PREPARE updClientesMigra FROM $sql;

	/************ FechaLimiteInferior **************/
	/* strcpy(sql, "SELECT TODAY-365 FROM dual ");

	strcpy(sql, "SELECT TODAY - t.valor FROM dual d, tabla t ");
	strcat(sql, "WHERE t.nomtabla = 'SAPFAC' ");
	strcat(sql, "AND t.sucursal = '0000' ");
	strcat(sql, "AND t.codigo = 'HISTO' ");
	strcat(sql, "AND t.fecha_activacion <= TODAY ");
	strcat(sql, "AND (t.fecha_desactivac IS NULL OR t.fecha_desactivac > TODAY) ");
*/		
	$PREPARE selFechaLimInf FROM "SELECT fecha_pivote FROM sap_regi_cliente
      WHERE numero_cliente = 0";
   
	/*********** Correlativos Hacia Atras ***********/		
	strcpy(sql, "SELECT t.valor FROM tabla t ");
	strcat(sql, "WHERE t.nomtabla = 'SAPFAC' ");
	strcat(sql, "AND t.sucursal = '0000' ");
	strcat(sql, "AND t.codigo = 'CORR' ");
	strcat(sql, "AND t.fecha_activacion <= TODAY ");
	strcat(sql, "AND (t.fecha_desactivac IS NULL OR t.fecha_desactivac > TODAY) ");
	
	$PREPARE selCorrelativos FROM $sql;
	
   /*************** Fecha Vig.Tarifa****************/
	strcpy(sql, "SELECT MIN(fecha_lectura) FROM hislec ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND fecha_lectura > ? ");
	strcat(sql, "AND tipo_lectura NOT IN (5, 6, 7, 8) ");
   
   $PREPARE selVigTarifa FROM $sql;
	
   /********* Registra Corrida **********/
   $PREPARE insRegiCorrida FROM "INSERT INTO sap_regiextra (
      estructura, fecha_corrida, fecha_fin, parametros
      )VALUES( 'OPEBIM', ?, CURRENT, ?)";

   /******** Fecha Inicio busqueda *******/
   $PREPARE selFechaDesde FROM "SELECT fecha_limi_inf FROM sap_regi_cliente
      WHERE numero_cliente = 0";
   
   /******* Consumo Reactiva *******/
   $PREPARE selConsuReac FROM "SELECT h1.cons_reac + h2.cons_reac 
      FROM hisfac_adic h1, hisfac_adic h2
      WHERE h1.numero_cliente = ?
      AND h1.corr_facturacion = ?
      AND h2.numero_cliente = h1.numero_cliente
      AND h2.corr_facturacion = h1.corr_facturacion-1 ";

   /******* Lectura Reactiva *******/
   $PREPARE selLectuReac FROM "SELECT first 1 lectu_factu_reac 
      FROM hislec_reac
      WHERE numero_cliente = ?
      AND corr_facturacion = ?
      AND tipo_lectura IN (1,2,3,4) ";   
   
   /******* Lectura Reactiva Ajustada *******/
   $PREPARE selLectuReacRefac FROM "SELECT FIRST 1 h1.lectu_rectif_reac
      FROM hislec_refac_reac h1
      WHERE h1.numero_cliente = ?
      AND h1.corr_facturacion = ?
      AND h1.corr_refacturacion = ( SELECT MAX(h2.corr_refacturacion)
      	FROM hislec_refac_reac h2
      	WHERE h2.numero_cliente = h1.numero_cliente
      	AND h2.corr_facturacion = h1.corr_facturacion ) ";

   /******* Lectura Activa Ajustada *******/
   $PREPARE selLectuActiRefac FROM "SELECT FIRST 1 h1.lectura_rectif
      FROM hislec_refac h1
      WHERE h1.numero_cliente = ?
      AND h1.corr_facturacion = ?
      AND h1.corr_refacturacion = ( SELECT MAX(h2.corr_refacturacion)
      	FROM hislec_refac h2
      	WHERE h2.numero_cliente = h1.numero_cliente
      	AND h2.corr_facturacion = h1.corr_facturacion ) ";
   
   /******* Ini Ventana Agenda 1 *******
   $PREPARE selIniVentana1 FROM "SELECT fecha_generacion  FROM sap_agenda
      WHERE porcion = ?
      AND fecha_emision_real = ?" ;
	*/

   /* "SELECT MAX(a.fecha_generacion - 5) */
   $PREPARE selIniVentana1 FROM 
	   "SELECT MAX(a.fecha_generacion)
        FROM agenda a
		WHERE a.sucursal	       = ? 
		  AND a.sector             = ?
  		  AND a.fecha_emision     <  ? 
							/*		(SELECT x.fecha_emision_real
                              		  FROM agenda x
                              		  WHERE x.sucursal 			= a.sucursal
                                	    AND x.sector   			= a.sector
                                	    AND x.fecha_emision_real = ?)
							*/
  		  AND a.tipo_agenda = 'L'
  		  AND a.tipo_ciclo  = 'R'";

	
   /******* Ini Ventana Agenda 2 *******/	
   $PREPARE selIniVentana2 FROM "SELECT MAX(inicio_ventana) FROM sap_agenda
      WHERE porcion = ?
      AND ul = ?
      AND inicio_ventana <= ?
      AND tipo_ciclo = 'F' ";
   
   /******* Ini Ventana Agenda 3 *******/
   $PREPARE selIniVentana3 FROM "SELECT MIN(inicio_ventana) from sap_agenda
      WHERE porcion = ?
      AND ul = ?
      AND fecha_emision_real = ? ";
   
   /******* Leyenda CosPhi *******/
   $PREPARE selLeyenda FROM "SELECT evento, fecha_evento
      FROM rer_eventos_cabe
      WHERE numero_cliente = ? ";

   /******* FP Lectu  ******/         
   $PREPARE selFpLectu FROM "SELECT cons_activa_p1 + cons_activa_p2 
      FROM fp_lectu
      WHERE numero_cliente = ?
      AND corr_facturacion = ? ";
   
   /******* FP Lectu Reac ******/
   $PREPARE selFpLectuReac FROM "SELECT cons_reac_p1 + cons_reac_p2 
      FROM fp_lectu
      WHERE numero_cliente = ?
      AND corr_facturacion = ? ";
   
	/******** Data Medidores **********/
	$PREPARE selMedid1 FROM "SELECT modelo_medidor, NVL(tipo_medidor, 'A') FROM medid
		WHERE numero_cliente = ?
		AND numero_medidor = ?
		AND marca_medidor = ? 
		AND estado = 'I' ";

	$PREPARE selMedid2 FROM "SELECT FIRST 1 m1.modelo_medidor, NVL(m1.tipo_medidor, 'A') FROM medid m1
		WHERE m1.numero_cliente = ?
		AND m1.numero_medidor = ?
		AND m1.marca_medidor = ? 
		AND m1.fecha_ult_insta = (SELECT MAX(m2.fecha_ult_insta) FROM medid m2
			WHERE m2.numero_cliente = m1.numero_cliente
			AND m2.numero_medidor = m1.numero_medidor
			AND m2.marca_medidor = m1.marca_medidor) ";

	$PREPARE selMedidor1 FROM "SELECT FIRST 1 me.mod_codigo, NVL(mo.tipo_medidor, 'A')
		FROM medidor me, modelo mo
		WHERE me.numero_cliente = ?
		AND me.med_numero = ?
		AND me.mar_codigo = ?
		AND me.cli_tarifa= 'T1'
		AND mo.mar_codigo = me.mar_codigo
		AND mo.mod_codigo = me.mod_codigo ";

	$PREPARE selMedidor2 FROM "SELECT FIRST 1 me.mod_codigo, NVL(mo.tipo_medidor, 'A')
		FROM medidor me, modelo mo
		WHERE me.med_numero = ?
		AND me.mar_codigo = ?
		AND mo.mar_codigo = me.mar_codigo
		AND mo.mod_codigo = me.mod_codigo ";

	
	
}

void FechaGeneracionFormateada( Fecha )
char *Fecha;
{
	$char fmtFecha[9];
	
	memset(fmtFecha,'\0',sizeof(fmtFecha));
	
	$EXECUTE selFechaActualFmt INTO :fmtFecha;
	
	strcpy(Fecha, fmtFecha);
	
}

char * RutaArchivos( ruta, clave )
$char ruta[100];
$char clave[7];
{

	$EXECUTE selRutaPlanos INTO :ruta using :clave;

    if ( SQLCODE != 0 ){
        printf("ERROR.\nSe produjo un error al tratar de recuperar el path destino del archivo.\n");
        exit(1);
    }
    
    return ruta;
}
/*
long getCorrelativo(sTipoArchivo)
$char		sTipoArchivo[11];
{
$long iValor=0;

	$EXECUTE selCorrelativo INTO :iValor using :sTipoArchivo;
	
    if ( SQLCODE != 0 ){
        printf("ERROR.\nSe produjo un error al tratar de recuperar el correlativo del archivo tipo %s.\n", sTipoArchivo);
        exit(1);
    }	
    
    return iValor;
}
*/
short LeoCliente(regCli)
$ClsCliente *regCli;
{

   InicializaCliente(regCli);

	$FETCH curClientes INTO
      :regCli->numero_cliente,
      :regCli->corr_facturacion,
      :regCli->tarifa,
      :regCli->correlativo_ruta,
      :regCli->info_adic_lectura;

  if ( SQLCODE != 0 ){
    if(SQLCODE == 100){
      return 0;
    }else{
      printf("Error al leer Cursor de CLIENTES !!!\nProceso Abortado.\n");
      exit(1);	
    }
  }			

	return 1;	
}

void InicializaCliente(regCli)
$ClsCliente *regCli;
{
	rsetnull(CLONGTYPE, (char *) &(regCli->numero_cliente));
   rsetnull(CINTTYPE, (char *) &(regCli->corr_facturacion));
   memset(regCli->tarifa, '\0', sizeof(regCli->tarifa));
	rsetnull(CLONGTYPE, (char *) &(regCli->correlativo_ruta));   
   memset(regCli->info_adic_lectura, '\0', sizeof(regCli->info_adic_lectura));
   
}

void getPrimaLectura(lNroCliente, lFechaLectura)
$long lNroCliente;
$long *lFechaLectura;
{
   $long lFechaAux;
   
   $EXECUTE selPrimaLectura INTO :lFechaAux
      USING :lNroCliente;
      
   if(SQLCODE != 0){
      printf("No se pudo cargar primera lectura para cliente %ld.\n", lNroCliente);
      return;
   }

   *lFechaLectura = lFechaAux;
}

short LeoFactura(reg)
$ClsFactura *reg;
{
$long lCorrFactuFP;
 
   InicializaFactura(reg);
   
   $FETCH curFactura INTO
      :reg->numero_cliente, 
      :reg->corr_facturacion, 
      :reg->consumo_sum, 
      :reg->tarifa,
      :reg->indica_refact,
      :reg->fdesde, 
      :reg->fhasta,
      :reg->difdias,
      :reg->cons_61,
      :reg->fecha_facturacion,
      :reg->numero_factura,
      :reg->tipo_lectura,
      :reg->porcion,
      :reg->ul,
      :reg->cosenoPhi,
      :reg->corr_factu_anterior,
      :reg->sector,
      :reg->zona,
      :reg->nroMedidor,
      :reg->marcaMedidor,
      :reg->cteMedidor,
	  :reg->lecturaActivaBase,
      :reg->lecturaActivaCierre,
      :reg->sCodCop,
      :reg->consumo_sum2,
	  :reg->sSucursal,
	  :reg->consumoReactiva,
	  :reg->lecturaReactivaBase;


   if(SQLCODE != 0){
	  return 0;
   }

	/* Levantamos la data del medidor */
	$EXECUTE selMedid1 INTO :reg->modeloMedidor, :reg->tipo_medidor
		USING :reg->numero_cliente, :reg->nroMedidor, :reg->marcaMedidor;
		
	if(SQLCODE != 0){
		if(SQLCODE==100){
			$EXECUTE selMedid2 INTO :reg->modeloMedidor, :reg->tipo_medidor
				USING :reg->numero_cliente, :reg->nroMedidor, :reg->marcaMedidor;
				
			if(SQLCODE != 0){
				if(SQLCODE==100){
					$EXECUTE selMedidor1 INTO :reg->modeloMedidor, :reg->tipo_medidor
						USING :reg->numero_cliente, :reg->nroMedidor, :reg->marcaMedidor;

					if(SQLCODE != 0){
						if(SQLCODE==100){
							$EXECUTE selMedidor2 INTO :reg->modeloMedidor, :reg->tipo_medidor
								USING :reg->nroMedidor, :reg->marcaMedidor;
							
							if(SQLCODE != 0){
								printf("Cliente %ld Medidor %ld Marca %s - Error en selMedidor2\n", reg->numero_cliente, reg->nroMedidor, reg->marcaMedidor);
							}
						}else{
							printf("Cliente %ld Medidor %ld Marca %s - Error en selMedidor1\n", reg->numero_cliente, reg->nroMedidor, reg->marcaMedidor);
						}
					}
				}else{
					printf("Cliente %ld Medidor %ld Marca %s - Error en selMedid2\n", reg->numero_cliente, reg->nroMedidor, reg->marcaMedidor);
				}
			}
		}else{
			printf("Cliente %ld - Error en selMedid1\n", reg->numero_cliente);
		}
	}
		

   if(reg->consumo_sum <0){
	  lCorrFactuFP=reg->corr_facturacion - 1;
	  
	  $EXECUTE selFpLectu INTO :reg->consumo_sum USING :reg->numero_cliente, :lCorrFactuFP;
	  
	  if(SQLCODE != 0){
		 if(SQLCODE==100){
			if(reg->tarifa[2]=='B'){
			   reg->consumo_sum=reg->consumo_sum2;
			}else{
			   reg->consumo_sum=reg->lecturaActivaCierre;            
			}
		 }else{
			printf("Error al buscar FP_LECTU para cliente %ld correlativo %d\n", reg->numero_cliente, lCorrFactuFP);
		 }   
	  }
	  reg->cons_61= (reg->consumo_sum / (reg->fhasta - reg->fdesde)) * 61;
   }

   if(!getIniVentanaAgenda(reg)){
	  printf("Error buscando ventana para fecha %ld porcion %s UL %s\n", reg->fecha_facturacion, reg->porcion, reg->ul);
	  return 0;
   }

   return 1;
}

void InicializaFactura(reg)
$ClsFactura    *reg;
{

   rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   rsetnull(CINTTYPE, (char *) &(reg->corr_facturacion)); 
   rsetnull(CDOUBLETYPE, (char *) &(reg->consumo_sum)); 
   rsetnull(CDOUBLETYPE, (char *) &(reg->consumo_sum2));
   memset(reg->tarifa, '\0', sizeof(reg->tarifa));
   memset(reg->indica_refact, '\0', sizeof(reg->indica_refact));
   rsetnull(CLONGTYPE, (char *) &(reg->fdesde)); 
   rsetnull(CLONGTYPE, (char *) &(reg->fhasta));
   rsetnull(CINTTYPE, (char *) &(reg->difdias));
   rsetnull(CDOUBLETYPE, (char *) &(reg->cons_61));
   rsetnull(CLONGTYPE, (char *) &(reg->fecha_facturacion));
   rsetnull(CLONGTYPE, (char *) &(reg->numero_factura));
   rsetnull(CINTTYPE, (char *) &(reg->tipo_lectura));
   memset(reg->tipo_medidor, '\0', sizeof(reg->tipo_medidor));
   rsetnull(CDOUBLETYPE, (char *) &(reg->consumo_sum_reactiva));
   memset(reg->porcion, '\0', sizeof(reg->porcion));
   memset(reg->ul, '\0', sizeof(reg->ul));
   rsetnull(CDOUBLETYPE, (char *) &(reg->cosenoPhi));
   memset(reg->leyendaPhi, '\0', sizeof(reg->leyendaPhi));
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaEvento));
   memset(reg->sFechaEvento, '\0', sizeof(reg->sFechaEvento));

   rsetnull(CINTTYPE, (char *) &(reg->corr_factu_anterior));
   rsetnull(CINTTYPE, (char *) &(reg->sector));
   memset(reg->zona, '\0', sizeof(reg->zona));   
   rsetnull(CLONGTYPE, (char *) &(reg->nroMedidor));
   memset(reg->marcaMedidor, '\0', sizeof(reg->marcaMedidor));
   rsetnull(CDOUBLETYPE, (char *) &(reg->lecturaActivaBase));
   rsetnull(CDOUBLETYPE, (char *) &(reg->lecturaActivaCierre));
   memset(reg->sCodCop, '\0', sizeof(reg->sCodCop));

   memset(reg->modeloMedidor, '\0', sizeof(reg->modeloMedidor));   
   rsetnull(CDOUBLETYPE, (char *) &(reg->cteMedidor));
	  
   rsetnull(CDOUBLETYPE, (char *) &(reg->lecturaReactivaBase));
   rsetnull(CDOUBLETYPE, (char *) &(reg->lecturaReactivaCierre));   
   rsetnull(CDOUBLETYPE, (char *) &(reg->consumoReactiva));
   
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaVentana));
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaIniVentana));
}


short LeoAhorro(regAhorro)
$ClsAhorroHist    *regAhorro;
{
   InicializaAhorro(regAhorro);
   
   $FETCH curAhorro INTO
	  :regAhorro->numero_cliente,
	  :regAhorro->corr_fact_act,
	  :regAhorro->lFechaInicio,
	  :regAhorro->sFechaInicio,
	  :regAhorro->lFechaFin,
	  :regAhorro->sFechaFin,
	  :regAhorro->consumo_61dias_act,
	  :regAhorro->dias_per_act;

   if(SQLCODE != 0){
	  return 0;
   }

   return 1;
}

void InicializaAhorro(regAhorro)
$ClsAhorroHist    *regAhorro;
{

   rsetnull(CLONGTYPE, (char *) &(regAhorro->numero_cliente));
   rsetnull(CINTTYPE, (char *) &(regAhorro->corr_fact_act));
   rsetnull(CLONGTYPE, (char *) &(regAhorro->lFechaInicio));
   memset(regAhorro->sFechaInicio, '\0', sizeof(regAhorro->sFechaInicio)); 
   rsetnull(CLONGTYPE, (char *) &(regAhorro->lFechaFin));
   memset(regAhorro->sFechaFin, '\0', sizeof(regAhorro->sFechaFin));
   rsetnull(CDOUBLETYPE, (char *) &(regAhorro->consumo_61dias_act));
   rsetnull(CINTTYPE, (char *) &(regAhorro->dias_per_act));

}

short LeoRefac(reg)
$ClsFactura *reg;
{
   $double  kwhRefac=0.00;
   $double  kwhRefacReac=0.00;
   
   $FETCH curRefac INTO :kwhRefac, :kwhRefacReac;
   
   if(SQLCODE != 0){
	  return 0;
   }

   if(!risnull(CDOUBLETYPE, (char *) &kwhRefac))
	  reg->consumo_sum += kwhRefac;
   
   if(!risnull(CDOUBLETYPE, (char *) &kwhRefacReac))
	  reg->consumo_sum_reactiva += kwhRefacReac;
   
   reg->cons_61 = (reg->consumo_sum / reg->difdias) * 61;
   
   return 1;
}

void  TraspasoDatos(iMarca, regClie, lFechaAlta, regAhorro, regFact)
int            iMarca;
ClsCliente     regClie;
long           lFechaAlta;
ClsAhorroHist  regAhorro;
ClsFacts       *regFact;
{
   char  sAux[9];
   
   memset(sAux, '\0', sizeof(sAux));
   
   InicializaOperandos(regFact);

   rfmtdate(lFechaAlta, "yyyymmdd", sAux);

   regFact->numero_cliente = regAhorro.numero_cliente;
   if(iMarca == 1){
	  regFact->corr_facturacion = regAhorro.corr_fact_act;
   }else{
	  regFact->corr_facturacion = regAhorro.corr_fact_act + 1;
   }
   
   /* ANLAGE */
   sprintf(regFact->anlage, "T1%ld", regClie.numero_cliente);
   
   /* BIS1 */
   strcpy(regFact->bis1, "99990101");
   
   /* AUTO_INSER */
   strcpy(regFact->auto_inser, "X");
   
   /* OPERAND */
   if(iMarca == 1){
	  strcpy(regFact->operand, "QCONSBIMES");
   }else{
	  strcpy(regFact->operand, "FADIASPC");
   }
   
   /* AB */
   strcpy(regFact->ab, regAhorro.sFechaInicio);
   
   /* BIS2 */
   strcpy(regFact->bis2, regAhorro.sFechaFin);
   
   /* LMENGE */
   if(iMarca == 1){
	  sprintf(regFact->lmenge, "%.0lf", regAhorro.consumo_61dias_act);
   }else if(iMarca==2){
	  sprintf(regFact->lmenge, "%ld", regAhorro.dias_per_act);
   }
  
   /* TARIFART */
   strcpy(regFact->tarifart, regClie.tarifa);
   
   /* KONDIGR */
   strcpy(regFact->kondigr, "ENERGIA");
   
   alltrim(regFact->anlage, ' ');
   alltrim(regFact->bis1, ' ');
   alltrim(regFact->auto_inser, ' ');
   alltrim(regFact->operand, ' ');
   alltrim(regFact->ab, ' ');
   alltrim(regFact->bis2, ' ');
   alltrim(regFact->lmenge, ' ');
   alltrim(regFact->tarifart, ' ');
   alltrim(regFact->kondigr, ' ');

}


void  TraspasoDatosFactu(iMarca, regClie, regFactu, regFact)
int            iMarca;
ClsCliente     regClie;
ClsFactura  regFactu;
ClsFacts       *regFact;
{
   char  sAux[9];
   
   memset(sAux, '\0', sizeof(sAux));
   
   InicializaOperandos(regFact);


   regFact->numero_cliente = regFactu.numero_cliente;
   if(iMarca == 2 ){
	  regFact->corr_facturacion = regFactu.corr_facturacion + 1;
   }else{
	  regFact->corr_facturacion = regFactu.corr_facturacion;
   }
   
   /* ANLAGE */
   sprintf(regFact->anlage, "T1%ld", regClie.numero_cliente);
   
   /* BIS1 */
   strcpy(regFact->bis1, "99990101");
   
   /* AUTO_INSER */
   strcpy(regFact->auto_inser, "X");
   
   /* OPERAND */
   switch(iMarca){
	  case 1:
		 strcpy(regFact->operand, "QCONSBIMES");
		 break;
	  case 2:
		 strcpy(regFact->operand, "FADIASPC");
		 break;
	  case 3:
		 strcpy(regFact->operand, "QCONBFPACT");
		 break;
	  case 4:
		 strcpy(regFact->operand, "QCONBFPREAC");
		 break;
	  case 5:
		 strcpy(regFact->operand, "QCONTADOR");
		 break;
   }
   
   /* AB */
   if(iMarca==5){
	  strcpy(regFact->ab, regFactu.sFechaEvento);
   }else{
	  rfmtdate(regFactu.fdesde, "yyyymmdd", regFact->ab);
   }
   
   /* BIS2 */
   if(iMarca==5){
	  strcpy(regFact->bis2, "99991231");
   }else{
	  rfmtdate(regFactu.fhasta, "yyyymmdd", regFact->bis2);
   }
   
	  
   /* LMENGE */
   switch(iMarca){
	  case 1:
		 sprintf(regFact->lmenge, "%.0lf", regFactu.cons_61);
		 break;
	  case 2:
		 sprintf(regFact->lmenge, "%ld", regFactu.difdias);
		 break;
	  case 3:
		 if(regFactu.tipo_lectura == 1 || regFactu.tipo_lectura == 4){
			strcpy(regFact->lmenge, "0");
		 }else{
			sprintf(regFact->lmenge, "%.0lf", regFactu.consumo_sum);
		 }
		 break;
	  case 4:
		 if(regFactu.tipo_lectura == 1 || regFactu.tipo_lectura == 4){
			strcpy(regFact->lmenge, "0");
		 }else{
			sprintf(regFact->lmenge, "%.0lf", regFactu.consumo_sum_reactiva);
		 }
		 break;
	  case 5:
		 alltrim(regFactu.leyendaPhi, ' ');
		 sprintf(regFact->lmenge, "%s", regFactu.leyendaPhi);
		 break;
   }
   
  
   /* TARIFART */
   strcpy(regFact->tarifart, regClie.tarifa);
   
   /* KONDIGR */
   strcpy(regFact->kondigr, "ENERGIA");
   
   alltrim(regFact->anlage, ' ');
   alltrim(regFact->bis1, ' ');
   alltrim(regFact->auto_inser, ' ');
   alltrim(regFact->operand, ' ');
   alltrim(regFact->ab, ' ');
   alltrim(regFact->bis2, ' ');
   alltrim(regFact->lmenge, ' ');
   alltrim(regFact->tarifart, ' ');
   alltrim(regFact->kondigr, ' ');

}

void InicializaOperandos(regFact)
ClsFacts *regFact;
{

   memset(regFact->anlage, '\0', sizeof(regFact->anlage));
   memset(regFact->bis1, '\0', sizeof(regFact->bis1));
   memset(regFact->auto_inser, '\0', sizeof(regFact->auto_inser));
   memset(regFact->operand, '\0', sizeof(regFact->operand));
   memset(regFact->ab, '\0', sizeof(regFact->ab));
   memset(regFact->bis2, '\0', sizeof(regFact->bis2));
   memset(regFact->lmenge, '\0', sizeof(regFact->lmenge));
   memset(regFact->tarifart, '\0', sizeof(regFact->tarifart));
   memset(regFact->kondigr, '\0', sizeof(regFact->kondigr));

}

short ClienteYaMigrado(nroCliente, lFechaInicio, iFlagMigra)
$long	nroCliente;
$long *lFechaInicio;
int		*iFlagMigra;
{
   $long lFecha;
	$char	sMarca[2];
/*	
	if(gsTipoGenera[0]=='R'){
		return 0;	
	}
*/	
	memset(sMarca, '\0', sizeof(sMarca));
	
	$EXECUTE selClienteMigrado into :sMarca, :lFecha using :nroCliente;
		
	if(SQLCODE != 0){
		if(SQLCODE==SQLNOTFOUND){
			*iFlagMigra=1; /* Indica que se debe hacer un insert */
			return 0;
		}else{
			printf("Error al verificar si el cliente %ld ya había sido migrado.\n", nroCliente);
			exit(1);
		}
	}
	
	if(strcmp(sMarca, "S")==0){
		*iFlagMigra=2; /* Indica que se debe hacer un update */
	  if(gsTipoGenera[0]=='G'){	
			/*return 1;*/
	  }
	}else{
		*iFlagMigra=2; /* Indica que se debe hacer un update */	
	}
		
   *lFechaInicio = lFecha;

	return 0;
}


void GenerarPlanos(fpSalida, regCli, regFact)
FILE        *fpSalida;
ClsCliente  regCli;
ClsFactura  regFact;
{
	char	sLinea[1000];
   int   iRcv;
   char  sFDesde[11];
   char  sFHasta[11];
   char  sFIniVentana[11];
   char  sFVentana[11];
   
   double   dConsumoActivo;
   double   dConsumoReactivo;
	
	memset(sLinea, '\0', sizeof(sLinea));
   memset(sFDesde, '\0', sizeof(sFDesde));
   memset(sFHasta, '\0', sizeof(sFHasta));
   memset(sFIniVentana, '\0', sizeof(sFIniVentana));
   memset(sFVentana, '\0', sizeof(sFVentana));
   
   rfmtdate(regFact.fdesde, "dd/mm/yyyy", sFDesde); /* long to char */
   rfmtdate(regFact.fhasta, "dd/mm/yyyy", sFHasta); /* long to char */
   rfmtdate(regFact.lFechaIniVentana, "dd/mm/yyyy", sFIniVentana); /* long to char */
   rfmtdate(regFact.lFechaVentana, "dd/mm/yyyy", sFVentana); /* long to char */
   
   
   /*	POD */
   sprintf(sLinea, "AR103E%0.8ld|", regCli.numero_cliente);
	
   /* SECTOR */
   sprintf(sLinea, "%s%d|", sLinea, regFact.sector);
   
   /* GRUPPO CLIENTI */
   strcat(sLinea, "T1|");
   
   /* RUTA radio */
   sprintf(sLinea, "%s%s|", sLinea, regFact.zona);
   
   /* SISTEMA */
   strcat(sLinea, "MWM|");
   
   /* MANIFACTURER */
   sprintf(sLinea, "%s%s|", sLinea, regFact.marcaMedidor);
   
   /* MODEL */
   sprintf(sLinea, "%s%s|", sLinea, regFact.modeloMedidor);
   
   /* SERIAL NUMBER */
   sprintf(sLinea, "%s%0.9ld|", sLinea, regFact.nroMedidor);
   
   /* DATA LETTURA ANTERIORE */
   sprintf(sLinea, "%s%s|", sLinea, sFDesde);
   
   /* LETTURA ENERGIA ATTIVA HP PRELEVATA ANTERIORE F2 */
   strcat(sLinea, "0|");
   /* LETTURA ENERGIA UFER HP REATTIVA ANTERIORE F1 */
   strcat(sLinea, "0|");
   /* LETTURA ENERGIA DNCR HP REATTIVA ANTERIORE F2 */
   strcat(sLinea, "0|");
   /* LETTURA POTENZA ATTIVA HP PRELEVATA ANTERIORE F2 */
   strcat(sLinea, "0|");
   
   /* LETTURA ENERGIA ATTIVA FP PRELEVATA ANTERIORE F3 */
   sprintf(sLinea, "%s%.0f|", sLinea, regFact.lecturaActivaBase);
   
   /* LETTURA ENERGIA UFER FP REATTIVA ANTERIORE F3 */
   if(regFact.tipo_medidor[0]== 'R'){
	  if(regFact.lecturaReactivaBase > 0){
		 sprintf(sLinea, "%s%.0f|", sLinea, regFact.lecturaReactivaBase);
	  }else{
		 strcat(sLinea, "0|");
	  }
   }else{
	  strcat(sLinea, "0|");
   }
   
   /* LETTURA ENERGIA DNCR REATTIVA FP ANTERIORE F4 */
   strcat(sLinea, "0|");
   /* LETTURA POTENZA ATTIVA FP PRELEVATA ANTERIORE F3 */
   strcat(sLinea, "0|");
   /* LETTURA ENERGIA ATTIVA HR PRELEVATA ANTERIORE F1 */
   strcat(sLinea, "0|");
   /* LETTURA ENERGIA UFER HR REATTIVA ANTERIORE F5 */
   strcat(sLinea, "0|");
   /* LETTURA ENERGIA DNCR HR REATTIVA ANTERIORE F6 */
   strcat(sLinea, "0|");
   /* LETTURA POTENZA ATTIVA HR PRELEVATA ANTERIORE F1 */
   strcat(sLinea, "0|");
   /* ENERGIA ATTIVA HP PRELEVATA MEDIO F2 */
   strcat(sLinea, "0|");
   /* ENERGIA UFER HP REATTIVA MEDIO F1 */
   strcat(sLinea, "0|");
   /* ENERGIA DNCR HP REATTIVA MEEDIO F2 */
   strcat(sLinea, "0|");
   /* POTENZA ATTIVA HP PRELEVATA MEDIO F2 */
   strcat(sLinea, "0|");
   
   /* ENERGIA ATTIVA FP PRELEVATA MEDIO F3 */
   sprintf(sLinea, "%s%.0f|", sLinea, regFact.consumo_sum);
   
   /* ENERGIA UFER FP REATTIVA MEDIO F3 */
   if(regFact.tipo_medidor[0]== 'R'){
	  if(regFact.consumoReactiva > 0){
		 sprintf(sLinea, "%s%.0f|", sLinea, regFact.consumoReactiva);
	  }else{
		 strcat(sLinea, "0|");
	  }
   }else{
		 strcat(sLinea, "0|");
   }
   
   
   /* ENERGIA DNCR REATTIVA FP MEDIO F4 */
   strcat(sLinea, "0|");
   /* POTENZA ATTIVA FP PRELEVATA MEDIO F3 */
   strcat(sLinea, "0|");
   /* ENERGIA ATTIVA HR PRELEVATA MEDIA F1 */
   strcat(sLinea, "0|");
   /* ENERGIA UFER HR REATTIVA MEDIA F5 */
   strcat(sLinea, "0|");
   /* ENERGIA DNCR HR REATTIVA MEDIA F6 */
   strcat(sLinea, "0|");
   /* POTENZA ATTIVA HR PRELEVATA MEDIA F1 */
   strcat(sLinea, "0|");
   /* ENERGIA ATTIVA HP PRELEVATA MINIMO F2 */
   strcat(sLinea, "0|");
   /* ENERGIA UFER HP REATTIVA MINIMO F1 */
   strcat(sLinea, "0|");
   /* ENERGIA DNCR HP REATTIVA MINIMO F2 */
   strcat(sLinea, "0|");
   /* POTENZA ATTIVA HP PRELEVATA MINIMO F2 */
   strcat(sLinea, "0|");
   /* ENERGIA ATTIVA FP PRELEVATA MINIMO F3 */
   strcat(sLinea, "0|");
   /* ENERGIA UFER FP REATTIVA MINIMO F3 */
   strcat(sLinea, "0|");
   /* ENERGIA DNCR REATTIVA FP MINIMO F4 */
   strcat(sLinea, "0|");
   /* POTENZA ATTIVA FP PRELEVATA MINIMO F3 */
   strcat(sLinea, "0|");
   /* ENERGIA ATTIVA HR PRELEVATA MINIMA F1 */
   strcat(sLinea, "0|");
   /* ENERGIA UFER HR REATTIVA MINIMA F5 */
   strcat(sLinea, "0|");
   /* ENERGIA DNCR HR REATTIVA MINIMA F6 */
   strcat(sLinea, "0|");
   /* POTENZA ATTIVA HR PRELEVATA MINIMA F1 */
   strcat(sLinea, "0|");
   /* ENERGIA ATTIVA HP PRELEVATA MASSIMO F2 */
   strcat(sLinea, "0|");
   /* ENERGIA UFER HP REATTIVA MASSIMO F1 */
   strcat(sLinea, "0|");
   /* ENERGIA DNCR HP REATTIVA MASSIMO F2 */
   strcat(sLinea, "0|");
   /* POTENZA ATTIVA HP PRELEVATA MASSIMO F2 */
   strcat(sLinea, "0|");
   /* ENERGIA ATTIVA FP PRELEVATA MASSIMO F3 */
   strcat(sLinea, "0|");
   /* ENERGIA UFER FP REATTIVA MASSIMO F3 */
   strcat(sLinea, "0|");
   /* ENERGIA DNCR REATTIVA FP MASSIMO F4 */
   strcat(sLinea, "0|");
   /* POTENZA ATTIVA FP PRELEVATA MASSIMO F3 */
   strcat(sLinea, "0|");
   /* ENERGIA ATTIVA HR PRELEVATA MASSIMA F1 */
   strcat(sLinea, "0|");
   /* ENERGIA UFER HR REATTIVA MASSIMA F5 */
   strcat(sLinea, "0|");
   /* ENERGIA DNCR HR REATTIVA MASSIMA F6 */
   strcat(sLinea, "0|");
   /* POTENZA ATTIVA HR PRELEVATA MASSIMA F1 */
   strcat(sLinea, "0|");
   /* ENER_ATT_HP_PREL_MAPREC_F2  */
   strcat(sLinea, "0|");
   /* ENER_UFER_HP_REAT_MAPREC_F1 */
   strcat(sLinea, "0|");
   /* ENER_DMCR_HP_REAT_MAPREC_F2 */
   strcat(sLinea, "0|");
   /* POT_ATT_HP_PREL_MAPREC_F2   */
   strcat(sLinea, "0|");
   /* ENER_ATT_FP_PREL_MAPREC_F3  */
   strcat(sLinea, "0|");
   /* ENER_UFER_FP_REAT_MAPREC_F3 */
   strcat(sLinea, "0|");
   /* ENER_DMCR_FP_REAT_MAPREC_F4 */
   strcat(sLinea, "0|");
   /* POT_ATT_FP_PREL_MAPREC_F3   */
   strcat(sLinea, "0|");
   /* ENER_ATT_HR_PREL_MAPREC_F1  */
   strcat(sLinea, "0|");
   /* ENER_UFER_HR_REAT_MAPREC_F5 */
   strcat(sLinea, "0|");
   /* ENER_DMCR_HR_REAT_MAPREC_F6 */
   strcat(sLinea, "0|");
   /* POT_ATT_HR_PREL_MAPREC_F1 */
   strcat(sLinea, "0|");
   
   
   /* DATA LETTURA ACTUAL */
   sprintf(sLinea, "%s%s|", sLinea, sFVentana);
   
   /* COSTANTE ENERGIA HP ATTIVA PRELEVATA F2 */
   strcat(sLinea, "|");
   /* COSTANTE ENERGIA UFER HP REATTIVA F1 */
   strcat(sLinea, "|");
   /* COSTANTE ENERGIA DNCR HP REATTIVA F2 */
   strcat(sLinea, "|");
   /* COSTANTE POTENZA HP ATTIVA PRELEVATA F2 */
   strcat(sLinea, "|");
   
   /* COSTANTE ENERGIA FP ATTIVA PRELEVATA F3 */
   sprintf(sLinea, "%s%.0f|", sLinea, regFact.cteMedidor);
   
   /* COSTANTE ENERGIA UFER FP REATTIVA F3 */
   if(regFact.tipo_medidor[0]== 'R'){
	  sprintf(sLinea, "%s%.0f|", sLinea, regFact.cteMedidor);
   }else{
	  strcat(sLinea, "|");
   }
   
   /* COSTANTE ENERGIA DNCR FP REATTIVA F4 */
   strcat(sLinea, "|");
   /* COSTANTE POTENZA FP ATTIVA PRELEVATA F3 */
   strcat(sLinea, "|");
   
   /* CONSUMO MINIMO ATTIVA F3 */
   strcat(sLinea, "9999999|");
   
   /* COSTANTE ENERGIA HR ATTIVA PRELEVATA F1 */
   strcat(sLinea, "|");
   /* COSTANTE ENERGIA UFER HR REATTIVA F5 */
   strcat(sLinea, "|");
   /* COSTANTE ENERGIA DNCR HR REATTIVA F6 */
   strcat(sLinea, "|");
   /* COSTANTE POTENZA HR ATTIVA PRELEVATA F1 */
   strcat(sLinea, "|");
   
   /* ENERGIA ATTIVA HP PRELEVATA MEDIO F2 (promedio 3 meses) */
   strcat(sLinea, "0|");
   /* ENERGIA UFER HP REATTIVA MEDIO F1  (promedio 3 meses) */
   strcat(sLinea, "0|");
   /* ENERGIA DNCR HP REATTIVA MEEDIO F2  (promedio 3 meses) */
   strcat(sLinea, "0|");
   /* POTENZA ATTIVA HP PRELEVATA MEDIO F2  (promedio 3 meses) */
   strcat(sLinea, "0|");
   /* ENERGIA ATTIVA FP PRELEVATA MEDIO F3  (promedio 3 meses) */
   strcat(sLinea, "0|");
   /* ENERGIA UFER FP REATTIVA MEDIO F3  (promedio 3 meses) */
   strcat(sLinea, "0|");
   /* ENERGIA DNCR REATTIVA FP MEDIO F4  (promedio 3 meses) */
   strcat(sLinea, "0|");
   /* POTENZA ATTIVA FP PRELEVATA MEDIO F3  (promedio 3 meses) */
   strcat(sLinea, "0|");
   /* ENERGIA ATTIVA HR PRELEVATA MEDIA F1  (promedio 3 meses) */
   strcat(sLinea, "0|");
   /* ENERGIA UFER HR REATTIVA MEDIA F5  (promedio 3 meses) */
   strcat(sLinea, "0|");
   /* ENERGIA DNCR HR REATTIVA MEDIA F6  (promedio 3 meses) */
   strcat(sLinea, "0|");
   /* POTENZA ATTIVA HR PRELEVATA MEDIA F1  (promedio 3 meses) */
   strcat(sLinea, "0|");
   /* ENERGIA ATTIVA HP PRELEVATA MEDIO F2 (promedio 6 meses) */
   strcat(sLinea, "0|");
   /* ENERGIA UFER HP REATTIVA MEDIO F1  (promedio 6 meses) */
   strcat(sLinea, "0|");
   /* ENERGIA DNCR HP REATTIVA MEEDIO F2  (promedio 6 meses) */
   strcat(sLinea, "0|");
   /* POTENZA ATTIVA HP PRELEVATA MEDIO F2  (promedio 6 meses) */
   strcat(sLinea, "0|");
   /* ENERGIA ATTIVA FP PRELEVATA MEDIO F3  (promedio 6 meses) */
   strcat(sLinea, "0|");
   /* ENERGIA UFER FP REATTIVA MEDIO F3  (promedio 6 meses) */
   strcat(sLinea, "0|");
   /* ENERGIA DNCR REATTIVA FP MEDIO F4  (promedio 6 meses) */
   strcat(sLinea, "0|");
   /* POTENZA ATTIVA FP PRELEVATA MEDIO F3  (promedio 6 meses) */
   strcat(sLinea, "0|");
   /* ENERGIA ATTIVA HR PRELEVATA MEDIA F1  (promedio 6 meses) */
   strcat(sLinea, "0|");
   /* ENERGIA UFER HR REATTIVA MEDIA F5  (promedio 6 meses) */
   strcat(sLinea, "0|");
   /* ENERGIA DNCR HR REATTIVA MEDIA F6  (promedio 6 meses) */
   strcat(sLinea, "0|");
   /* POTENZA ATTIVA HR PRELEVATA MEDIA F1  (promedio 6 meses) */
   strcat(sLinea, "0|");
   /* CONSUMO FATTURATO MASSIMO */
   strcat(sLinea, "0|");
   
   /* ID_ORDEN_LECTURA */
   strcat(sLinea, "|");
   
   /* CODIGO_NOTIFICACIONES */
   strcat(sLinea, "0|");
   /* RECLAMO */
   strcat(sLinea, "0|");
   
   /* OBS_CLIENTE */
   alltrim(regCli.info_adic_lectura, ' ');
   sprintf(sLinea, "%s%s|", sLinea, regCli.info_adic_lectura);
   
   /* RECORRIDO */
   sprintf(sLinea, "%s%0.6ld|", sLinea, regCli.correlativo_ruta);
   
   /* UNIDAD_LECTURA */
   sprintf(sLinea, "%s%s|", sLinea, regFact.ul);
   
   /* CENTRO OPERATIVO */
   sprintf(sLinea, "%s%s|", sLinea, regFact.sCodCop);
   
   /* CMD_ACTIVA_F1 */
   strcat(sLinea, "0|");
   /* CMD_ACTIVA_F2 */
   strcat(sLinea, "0|");
   /* CMD_ACTIVA_F3 */
   strcat(sLinea, "0|");
   /* CMD_REACTIVA_F1 */
   strcat(sLinea, "0|");
   /* CMD_REACTIVA_F2 */
   strcat(sLinea, "0|");
   /* CMD_REACTIVA_F3 */
   strcat(sLinea, "0|");
   /* CMD_DEMANDA_F1 */
   strcat(sLinea, "0|");
   /* CMD_DEMANDA_F2 */
   strcat(sLinea, "0|");
   /* CMD_DEMANDA_F3 */
   strcat(sLinea, "0|");

   strcat(sLinea, "\n");
   
	iRcv=fprintf(fpSalida, sLinea);
   if(iRcv < 0){
	  printf("Error al escribir archivo\n");
	  exit(1);
   }	

}


void GeneraKey(fpSalida, iMarca, regFact)
FILE     *fpSalida;
int      iMarca;
ClsFacts regFact;
{
	char	sLinea[1000];	
   char  sMarca[3];
   int   iRcv;
	   
	memset(sLinea, '\0', sizeof(sLinea));
   memset(sMarca, '\0', sizeof(sMarca));

   switch(iMarca){
	  case 1:
	  case 3:
	  case 4:
	  case 5:
		 strcpy(sMarca, "QC");
		 break;
	  case 2:
		 strcpy(sMarca, "FP");
		 break;
   }

   /* llave */
   sprintf(sLinea, "T1%ld-%ld%s\tKEY\t", regFact.numero_cliente, regFact.corr_facturacion, sMarca);
   
   /* ANLAGE */
   sprintf(sLinea, "%s%s\t", sLinea, regFact.anlage);

   /* BIS1 */
   sprintf(sLinea, "%s%s", sLinea, regFact.bis1);
   
   strcat(sLinea, "\n");
   
	iRcv=fprintf(fpSalida, sLinea);
   if(iRcv < 0){
	  printf("Error al escribir KEY\n");
	  exit(1);
   }	


}

void GeneraCuerpo(fpSalida, iMarca, regFact)
FILE     *fpSalida;
int      iMarca;
ClsFacts regFact;
{
	char	sLinea[1000];
   int   iRcv;
	
	memset(sLinea, '\0', sizeof(sLinea));

   /* llave */
   switch(iMarca){
	  case 1:
	  case 3:
	  case 4:
	  case 5:
		 sprintf(sLinea, "T1%ld-%ldQC\tF_QUAN\t", regFact.numero_cliente, regFact.corr_facturacion);
		 break;
	  case 2:
		 sprintf(sLinea, "T1%ld-%ldFP\tF_FACT\t", regFact.numero_cliente, regFact.corr_facturacion);
		 break;
   }

   /* OPERAND */
   sprintf(sLinea, "%s%s\t", sLinea, regFact.operand);

   /* AUTO_INSER */
   sprintf(sLinea, "%s%s", sLinea, regFact.auto_inser);
   
   strcat(sLinea, "\n");
   
	iRcv=fprintf(fpSalida, sLinea);
   if(iRcv < 0){
	  printf("Error al escribir Cuerpo\n");
	  exit(1);
   }	

}

void GeneraPie(fpSalida, iMarca, regFact)
FILE     *fpSalida;
int      iMarca;
ClsFacts regFact;
{
	char	sLinea[1000];	
   int   iRcv;
	
	memset(sLinea, '\0', sizeof(sLinea));

   /* llave */
   switch(iMarca){
	  case 1:
	  case 3:
	  case 4:
	  case 5:
		 sprintf(sLinea, "T1%ld-%ldQC\tV_QUAN\t", regFact.numero_cliente, regFact.corr_facturacion);
		 break;
	  case 2:
		 sprintf(sLinea, "T1%ld-%ldFP\tV_FACT\t", regFact.numero_cliente, regFact.corr_facturacion);
		 break;
   }
   
   /* AB */
   sprintf(sLinea, "%s%s\t", sLinea, regFact.ab);
   
   /* BIS2 */
   sprintf(sLinea, "%s%s\t", sLinea, regFact.bis2);
   
   /* LMENGE */
   sprintf(sLinea, "%s%s\t", sLinea, regFact.lmenge);
   
   /* TARIFART */
   sprintf(sLinea, "%s%s\t", sLinea, regFact.tarifart);
   
   /* KONDIGR */
   sprintf(sLinea, "%s%s", sLinea, regFact.kondigr);
   
   strcat(sLinea, "\n");
   
	iRcv=fprintf(fpSalida, sLinea);
   if(iRcv < 0){
	  printf("Error al escribir Pie\n");
	  exit(1);
   }	

}


void GeneraENDE(fpSalida, iMarca, regFact)
FILE     *fpSalida;
int      iMarca;
ClsFacts regFact;
{
	char	sLinea[1000];
   char  sMarca[3];
   int   iRcv;	

	memset(sLinea, '\0', sizeof(sLinea));
   memset(sMarca, '\0', sizeof(sMarca));
   
   switch(iMarca){
	  case 1:
	  case 3:
	  case 4:
	  case 5:
		 strcpy(sMarca, "QC");
		 break;
	  case 2:
		 strcpy(sMarca, "FP");
		 break;
   }
	
   sprintf(sLinea, "T1%ld-%ld%s\t&ENDE", regFact.numero_cliente, regFact.corr_facturacion, sMarca);
   
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fpSalida, sLinea);
   if(iRcv < 0){
	  printf("Error al escribir ENDE\n");
	  exit(1);
   }	
	
}
/*
short RegistraArchivo(void)
{
	$long	lCantidad;
	$char	sTipoArchivo[10];
	$char	sNombreArchivo[100];
	
	
	if(cantProcesada > 0){
		strcpy(sTipoArchivo, "FACTSBIM");
		strcpy(sNombreArchivo, sArchQConsBimesUnx);
	  
		lCantidad=cantProcesada;
				
		$EXECUTE updGenArchivos using :sTipoArchivo;
			
		$EXECUTE insGenInstal using
				:gsTipoGenera,
				:lCantidad,
				:glNroCliente,
				:sNombreArchivo;
	}
	
	return 1;
}
*/
short RegistraCliente(nroCliente, cantConsu, cantActi, iFlagMigra)
$long	nroCliente;
$long  cantConsu;
$long  cantActi;
int		iFlagMigra;
{
	
	if(iFlagMigra==1){
		$EXECUTE insClientesMigra using :nroCliente, :cantConsu, :cantConsu, :cantActi;
	}else{
		$EXECUTE updClientesMigra using :cantConsu, :cantConsu, :cantActi, :nroCliente;
	}

	return 1;
}

short getConsuReactiva(reg)
$ClsFactura *reg;
{

   $EXECUTE selConsuReac INTO :reg->consumo_sum_reactiva
	  USING :reg->numero_cliente,
			:reg->corr_facturacion;
	  
   if(SQLCODE != 0){
	  return 0;
   }
   return 1;
}

short getLectuActivaRefac(reg)
$ClsFactura *reg;
{
   $EXECUTE selLectuActiRefac INTO :reg->lecturaActivaCierre
	  USING :reg->numero_cliente,
			:reg->corr_facturacion;

   if(SQLCODE != 0){
	  return 0;
   }

   $EXECUTE selLectuActiRefac INTO :reg->lecturaActivaBase
	  USING :reg->numero_cliente,
			:reg->corr_factu_anterior;

   if(SQLCODE != 0){
	  return 0;
   }

   reg->consumo_sum= reg->lecturaActivaCierre - reg->lecturaActivaBase;

   return 1;
}

short getLectuReactiva(reg)
$ClsFactura *reg;
{
$long lCorrFactuFP;

   $EXECUTE selLectuReac INTO :reg->lecturaReactivaCierre
	  USING :reg->numero_cliente,
			:reg->corr_facturacion;

   if(SQLCODE != 0){
	  return 0;
   }
   
   $EXECUTE selLectuReac INTO :reg->lecturaReactivaBase
	  USING :reg->numero_cliente,
			:reg->corr_factu_anterior;

   if(SQLCODE != 0){
	  return 0;
   }
   
   reg->consumoReactiva= reg->lecturaReactivaCierre - reg->lecturaReactivaBase;
   
   if(reg->consumoReactiva < 0){
	  lCorrFactuFP=reg->corr_facturacion - 1;

	  $EXECUTE selFpLectuReac INTO :reg->consumoReactiva
		 USING :reg->numero_cliente,
			   :lCorrFactuFP;

	  if(SQLCODE !=0){
		 $EXECUTE selLectuReac INTO :reg->consumoReactiva
			USING :reg->numero_cliente,
				  :reg->corr_facturacion;
				  
		 if(SQLCODE !=0){
			printf("No se encontró consumo reactiva para cliente %ld correlativo %ld\n", reg->numero_cliente, reg->corr_facturacion);
		 }
	  }
   }
   
   return 1;
}

short getLectuReactivaRefac(reg)
$ClsFactura *reg;
{

   $EXECUTE selLectuReacRefac INTO :reg->lecturaReactivaCierre
	  USING :reg->numero_cliente,
			:reg->corr_facturacion;

   if(SQLCODE != 0){
	  return 0;
   }

   $EXECUTE selLectuReacRefac INTO :reg->lecturaReactivaBase
	  USING :reg->numero_cliente,
			:reg->corr_factu_anterior;

   if(SQLCODE != 0){
	  return 0;
   }

   reg->consumoReactiva= reg->lecturaReactivaCierre - reg->lecturaReactivaBase;
   
   return 1;
}

short getIniVentanaAgenda(reg)
$ClsFactura *reg;
{
   $long lFecha;
   
	if (strcmp(reg->sSucursal, "ESFP") == 0) /* es un flag */
	{
		reg->lFechaVentana = reg->fecha_facturacion; /* no es la fecha de fact, en estos registros grabo la fecha de agenda */
		return 1;
	}
   
   /* Ventana de inicio */
   
   /* Ventana de cierre */
   rsetnull(CLONGTYPE, (char *) &(lFecha));
   
   $EXECUTE selIniVentana1 
		INTO :lFecha
	  USING :reg->sSucursal,
			:reg->sector,
			:reg->fecha_facturacion;

	reg->lFechaVentana = lFecha;
	return SQLCODE != SQLNOTFOUND;

/*
   if(SQLCODE != 0 || risnull(CLONGTYPE, (char *) &lFecha)){
	  $EXECUTE selIniVentana2 INTO :lFecha
		 USING :reg->porcion,
			   :reg->ul,
			   :reg->fhasta;
   }            

   if(SQLCODE != 0 || risnull(CLONGTYPE, (char *) &lFecha) || lFecha < reg->fdesde){

	  $EXECUTE selIniVentana3 INTO :lFecha
		 USING :reg->porcion,
			   :reg->ul,
			   :reg->fecha_facturacion;
   
	  reg->lFechaVentana = lFecha;
	  if(SQLCODE != 0 || risnull(CLONGTYPE, (char *) &lFecha)){
		 return 0;
	  }
   }else{
	  reg->lFechaVentana = lFecha;
   }
	  
   return 1;
*/
}

short getLeyenda(reg, lValTarifa)
$ClsFactura *reg;
$long       lValTarifa;
{

   $EXECUTE selLeyenda INTO :reg->leyendaPhi,
							:reg->lFechaEvento;
							
   if(SQLCODE != 0){
	  return 0;
   }

   if(reg->lFechaEvento < lValTarifa)
	  reg->lFechaEvento = lValTarifa;
	  
   rfmtdate(reg->lFechaEvento, "yyyymmdd", reg->sFechaEvento); /* long to char */   

   return 1;
}

/****************************
		GENERALES
*****************************/

void command(cmd,buff_cmd)
char *cmd;
char *buff_cmd;
{
   FILE *pf;
   char *p_aux;
   pf =  popen(cmd, "r");
   if (pf == NULL)
	   strcpy(buff_cmd, "E   Error en ejecucion del comando");
   else
	   {
	   strcpy(buff_cmd,"\n");
	   while (fgets(buff_cmd + strlen(buff_cmd),512,pf))
		   if (strlen(buff_cmd) > 5000)
			  break;
	   }
   p_aux = buff_cmd;
   *(p_aux + strlen(buff_cmd) + 1) = 0;
   pclose(pf);
}

char *strReplace(sCadena, cFind, cRemp)
char sCadena[1000];
char cFind[2];
char cRemp[2];
{
	char sNvaCadena[1000];
	int lLargo;
	int lPos;
	int dPos=0;
	
	lLargo=strlen(sCadena);

	for(lPos=0; lPos<lLargo; lPos++){

		if(sCadena[lPos]!= cFind[0]){
			sNvaCadena[dPos]=sCadena[lPos];
			dPos++;
		}else{
			if(strcmp(cRemp, "")!=0){
				sNvaCadena[dPos]=cRemp[0];	
				dPos++;
			}
		}
	}
	
	sNvaCadena[dPos]='\0';

	return sNvaCadena;
}

void CalcularConsumos1erTLI(reg)
$ClsFactura *reg;
{
	$long lCorrFactuFP = reg->corr_facturacion - 3;

	$EXECUTE selFpLectu 
		INTO  :reg->consumo_sum 
		USING :reg->numero_cliente, 
			  :lCorrFactuFP;

	if (strcmp(reg->tipo_medidor, "R") == 0)
	{
   		$EXECUTE selFpLectuReac 
		    INTO	:reg->consumoReactiva
			USING	:reg->numero_cliente,
              		:lCorrFactuFP;
	}	

}

/*
$ClsFactura *reg;
{
$long lCorrFactuFP;

   InicializaFactura(reg);

   $FETCH curFactura INTO
      :reg->numero_cliente,
      :reg->corr_facturacion,
      :reg->consumo_sum,
      :reg->tarifa,
      :reg->indica_refact,
      :reg->fdesde,
      :reg->fhasta,
      :reg->difdias,
      :reg->cons_61,
      :reg->fecha_facturacion,
      :reg->numero_factura,
      :reg->tipo_lectura,
      :reg->tipo_medidor,
      :reg->porcion,
      :reg->ul,
      :reg->cosenoPhi,
      :reg->corr_factu_anterior,
      :reg->sector,
      :reg->zona,
      :reg->nroMedidor,
      :reg->marcaMedidor,
      :reg->modeloMedidor,
      :reg->cteMedidor,

      :reG->lecturaActivaCierre,
:reg->lecturaActivaBase,
      :reg->sCodCop,
      :reg->consumo_sum2,
      :reg->sSucursal,
      :reg->consumoReactiva,



*/


void ImprimirTLIs(ClsCliente regCliente)
{
	int i;
	for (i=iCantFact - 1; i>0; i--)
	{
		
		tVecFacturas[i].lecturaActivaBase 	= tVecFacturas[i-1].lecturaActivaBase; 
		tVecFacturas[i].consumo_sum 		= tVecFacturas[i-1].consumo_sum;
/*		tVecFacturas[i].lecturaReactivaBase = tVecFacturas[i-1].lecturaReactivaBase; 
*/
		tVecFacturas[i].consumoReactiva     = tVecFacturas[i-1].consumoReactiva;

	}

    for (i=0; i < iCantFact; i++)
    {
		GenerarPlanos(fpUnx, regCliente, tVecFacturas[i]);
    }

}
