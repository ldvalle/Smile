/***********************************************************************************
    Proyecto: Migracion al sistema SMILE
    Aplicacion: sfc_device
    
	Fecha : 24/08/2021

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructura Measure & Counter y Consumos
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		<Tipo Corrida>: 0=Normal, 1=Reducida
		<Archivos Genera> 0=Todos, 1=Measures, 2=Consumos
**********************************************************************************/
#include <locale.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sm_delta_misura.h";

/* Variables Globales */
int   giTipoCorrida;
int   gsArchivoGenera;

FILE	*pFileMisuraPend;
FILE	*pFileMisuraAdjPend;

FILE	*pFileMisura;
FILE	*pFileMisuraAdj;
/*----------------------*/
char	sArchMisuraPendUnx[100];
char	sArchMisuraPendAux[100];
char	sArchMisuraPendDos[100];
char	sSoloArchivoPendMisura[100];

char	sArchMisuraActUnx[100];
char	sArchMisuraActAux[100];
char	sArchMisuraActDos[100];
char	sSoloArchivoMisuraAct[100];

char	sArchMisuraUnx[100];
char	sArchMisuraAux[100];
char	sArchMisuraDos[200];
char	sSoloArchivoMisura[100];
/*----------------------*/
char	sArchMisuraAdjPendUnx[100];
char	sArchMisuraAdjPendAux[100];
char	sArchMisuraAdjPendDos[100];
char	sSoloArchivoMisuraAdjPend[100];

char	sArchMisuraAdjUnx[100];
char	sArchMisuraAdjAux[100];
char	sArchMisuraAdjDos[100];
char	sSoloArchivoMisuraAdj[100];

char	sArchMisuraAdjActUnx[100];
char	sArchMisuraAdjActAux[100];
char	sArchMisuraAdjActDos[100];
char	sSoloArchivoMisuraAdjAct[100];
/*----------------------*/

char	sArchLog[100];
char	sPathSalida[100];
char  sPathCopia[1000];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];
long	lCorrelativo;

long	cantProcesada;
long 	cantPreexistente;
long	iContaLog;

char  gsDesdeFmt[9];
char  gsHastaFmt[9];

/* Variables Globales Host */
$ClsCliente	regCliente;
$ClsLectura	regLectura;
$ClsLectura regLectuPend;
$long 	glFechaDesde;
$long 	glFechaHasta;
$long    lFecha4Y;

char	sMensMail[1024];	

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
FILE	   *fp;
int		iFlagMigra=0;
int      iFlagEmpla=0;
int      iIndexFile=1;
int      iFilasFile;
$long    lNroCliente;
$long    lFechaPivote;
$long    lFechaMoveIn;
$int	 iCorrFacturacion;
$int	 iPlan;
$int	 iEstadoCliente;
$int	 iTipoLectuActual;
int		 iCantidadArchivos=0;
long     iCantLecturasActuales=0;
long	 iCantLecturasPendientes=0;
$int	 iCorrFactuActual;
$int	 iCorrFactuFutura;
$long 	 lFechaBaja;
$char	 sLstTiposLectu[10];

	if(! AnalizarParametros(argc, argv)){
		exit(0);
	}
	
   setlocale(LC_ALL, "en_US.UTF-8");
   
	hora = time(&hora);
	
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));
	
	strcpy(nombreBase, argv[1]);
	
	$DATABASE :nombreBase;	
	
	$SET LOCK MODE TO WAIT 600;
	$SET ISOLATION TO DIRTY READ;
	
	CreaPrepare();

	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
   /* $EXECUTE selFechaInicio INTO :lFecha4Y; */
   

	cantProcesada=0;
	cantPreexistente=0;
	iContaLog=0;
	
/******** INICIO DELTA MISURA ************/	
	if(!AbreArchivos()){
		exit(1);	
	}
	
	/* $OPEN curClientes USING :glFechaDesde, :glFechaHasta;*/
	$OPEN curClientes;
	
	while(LeoCliente(&regCliente)){
		alltrim(regCliente.sTipoOt, ' ');
		memset(sLstTiposLectu, '\0', sizeof(sLstTiposLectu));
		iContaLog=0;
		
		if(strcmp(regCliente.sTipoOt, "SS")==0){
			strcpy(sLstTiposLectu, "7");
		}else if(strcmp(regCliente.sTipoOt, "SC")==0){
			strcpy(sLstTiposLectu, "5,6");
		}else{
			strcpy(sLstTiposLectu, "5");
		}
		
		alltrim(sLstTiposLectu, ' ');
		
/*
		$OPEN curLecturas USING :regCliente.lNroCliente, 
			:sLstTiposLectu, :sLstTiposLectu, :regCliente.lFechaNovedad;
*/

		if(strcmp(regCliente.sTipoOt, "SS")==0){
			$OPEN curLecturas USING :regCliente.lNroCliente, :regCliente.lFechaNovedad;
		}else if(strcmp(regCliente.sTipoOt, "SC")==0){
			$OPEN curLecturasCM USING :regCliente.lNroCliente, :regCliente.lFechaNovedad;
		}else{
			$OPEN curLecturasRT USING :regCliente.lNroCliente, :regCliente.lFechaNovedad;
		}

	
		while(LeoLecturas(&regLectura, regCliente.lFechaMoveIn, regCliente.sTipoOt)){
			GenerarPlanoMisura(regLectura, 0, regCliente.iEstadoCliente, regCliente.lFechaBaja);
		 
			iCantLecturasActuales++; 
			iContaLog=1;     
		}
		
		if(iContaLog==0)
			printf("fallo Cliente %ld Tipo Ot %s Fecha Novedad %ld tipos lectu %s\n", regCliente.lNroCliente, regCliente.sTipoOt, regCliente.lFechaNovedad, sLstTiposLectu);
			
		/* $CLOSE curLecturas; */
		if(strcmp(regCliente.sTipoOt, "SS")==0){
			$CLOSE curLecturas;
		}else if(strcmp(regCliente.sTipoOt, "SC")==0){
			$CLOSE curLecturasCM;
		}else{
			$CLOSE curLecturasRT;
		}
		
		/* Actualizo Registro Cursor */
		$BEGIN WORK;
		
		$EXECUTE updOT USING :regCliente.lNroCliente, :regCliente.lFechaNovedad, :regCliente.sTipoOt;
		
		$COMMIT WORK;
		
		cantProcesada++;
	}	
	
	$CLOSE curClientes;
	
	CerrarArchivos();
	MoverArchivos(1);
	
/******** FIN DELTA MISURA ************/
	
	$CLOSE DATABASE;

	$DISCONNECT CURRENT;


	/* ********************************************
				FIN AREA DE PROCESO
	********************************************* */

	printf("==============================================\n");
	printf("SMILE :) - Delta MISURA\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Clientes Procesados : %ld \n", cantProcesada);
    printf("Cantidad de Lecturas Informadas: %ld \n", iCantLecturasActuales);
	printf("==============================================\n");
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));						

	hora = time(&hora);
	printf("\nHora de finalizacion del proceso : %s\n", ctime(&hora));


	exit(0);
}	

short AnalizarParametros(argc, argv)
int		argc;
char	* argv[];
{
   char  sFechaDesde[11];
   char  sFechaHasta[11];
   char  sFecha4Y[11];
   
   memset(sFecha4Y, '\0', sizeof(sFecha4Y));
   memset(sFechaDesde, '\0', sizeof(sFechaDesde));
   memset(sFechaHasta, '\0', sizeof(sFechaHasta));

   memset(gsDesdeFmt, '\0', sizeof(gsDesdeFmt));
   memset(gsHastaFmt, '\0', sizeof(gsHastaFmt));
   
	if(argc < 3 ){
		MensajeParametros();
		return 0;
	}
	
	giTipoCorrida=atoi(argv[2]);
   
   if(argc==5){
/*
	   strcpy(sFecha4Y, argv[3]);
	   rdefmtdate(&lFecha4Y, "dd/mm/yyyy", sFecha4Y); 
*/	   
      strcpy(sFechaDesde, argv[3]); 
      strcpy(sFechaHasta, argv[4]);
      
      sprintf(gsDesdeFmt, "%c%c%c%c%c%c%c%c", sFechaDesde[6], sFechaDesde[7],sFechaDesde[8],sFechaDesde[9],
                  sFechaDesde[3],sFechaDesde[4], sFechaDesde[0],sFechaDesde[1]);      

      sprintf(gsHastaFmt, "%c%c%c%c%c%c%c%c", sFechaHasta[6], sFechaHasta[7],sFechaHasta[8],sFechaHasta[9],
                  sFechaHasta[3],sFechaHasta[4], sFechaHasta[0],sFechaHasta[1]);      
      
      rdefmtdate(&glFechaDesde, "dd/mm/yyyy", sFechaDesde); 
      rdefmtdate(&glFechaHasta, "dd/mm/yyyy", sFechaHasta); 
   }else{
      glFechaDesde=-1;
      glFechaHasta=-1;
   }
	return 1;
}

void MensajeParametros(void){
	printf("Error en Parametros.\n");
	printf("	<Base> = synergia.\n");
	printf("	<Tipo Corrida> 0=Normal, 1=Reducida, 3=Delta.\n");
	printf("	<Fecha Desde Opcional> dd/mm/aaaa.\n");
	printf("	<Fecha Hasta Opcional> dd/mm/aaaa.\n");
      
}


short AbreArchivos(void)
{
   char  sTitulos[10000];
   $char sFecha[20];
   int   iRcv;
   
	memset(sTitulos, '\0', sizeof(sTitulos));

	memset(sArchMisuraUnx,'\0',sizeof(sArchMisuraUnx));
	memset(sArchMisuraAux,'\0',sizeof(sArchMisuraAux));
	memset(sArchMisuraDos,'\0',sizeof(sArchMisuraDos));
	memset(sSoloArchivoMisura,'\0',sizeof(sSoloArchivoMisura));

	memset(sFecha,'\0',sizeof(sFecha));
	memset(sPathSalida,'\0',sizeof(sPathSalida));

	FechaGeneracionFormateada(sFecha);
	alltrim(sFecha, ' ');
   
	RutaArchivos( sPathSalida, "SMIGEN" );
	alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SMICPY" );
	alltrim(sPathCopia,' ');
	strcat(sPathCopia, "Anagrafica/Nove");

	sprintf( sArchMisuraUnx  , "%sLEITURA_T1_NOV.unx", sPathSalida );
	sprintf( sArchMisuraAux  , "%sLEITURA_T1_NOV.aux", sPathSalida );
	sprintf( sArchMisuraDos  , "%sLEITURA_T1_NOV_%s.txt", sPathSalida, sFecha);

	pFileMisura=fopen( sArchMisuraDos, "w" );
	
	if( !pFileMisura ){
		printf("ERROR al abrir archivo %s.\n", sArchMisuraDos );
		return 0;
	}


	return 1;	
}

void CerrarArchivos(void)
{
	fclose(pFileMisura);
	/*fclose(pFileMisuraAdj);*/

}

void MoverArchivos(iFlag)
int	iFlag;
{
char	sCommand[10000];
int	iRcv, i;
	
	
	/* ------- Misura ------ */
/*	
	sprintf(sCommand, "iconv -f WINDOWS-1252 -t UTF-8 %s > %s ", sArchMisuraUnx, sArchMisuraDos);
	iRcv=system(sCommand);
*/
	sprintf(sCommand, "chmod 777 %s", sArchMisuraDos);
	iRcv=system(sCommand);


	sprintf(sCommand, "mv %s %s", sArchMisuraDos, sPathCopia);
	iRcv=system(sCommand);
/*
	if(iRcv >= 0){        
		sprintf(sCommand, "rm %s", sArchMisuraUnx);
		iRcv=system(sCommand);
	}         
*/  
}

void CreaPrepare(void){
$char sql[10000];
$char sAux[1000];

	memset(sql, '\0', sizeof(sql));
	memset(sAux, '\0', sizeof(sAux));
	

	/******** Fecha Actual Formateada ****************/
	strcpy(sql, "SELECT TO_CHAR(CURRENT, '%Y%m%d%H%M%S') FROM dual ");
	
	$PREPARE selFechaActualFmt FROM $sql;

	/******** Fecha Actual  ****************/
	strcpy(sql, "SELECT TO_CHAR(TODAY, '%d/%m/%Y') FROM dual ");
	
	$PREPARE selFechaActual FROM $sql;	

   /* Fecha Inicio Lecturas */
   $PREPARE selFechaInicio FROM "SELECT TODAY - 1460 FROM dual ";
   
	/******** Cursor CLIENTES  ****************/	
	strcpy(sql, "SELECT c.numero_cliente, s.fecha_novedad, s.tipo_ot, c.corr_facturacion, c.estado_cliente, NVL(p.fecha_move_in, s.fecha_novedad - 365)");
	strcat(sql, "FROM ot_anagrafica s, cliente c, OUTER sap_regi_cliente p ");
	strcat(sql, "WHERE s.fecha_unlock IS NOT NULL ");
	strcat(sql, "AND s.fecha_envia_misura IS NULL ");
	/*strcat(sql, "AND s.fecha_novedad between ? AND ? ");*/
	strcat(sql, "AND c.numero_cliente = s.numero_cliente ");
	strcat(sql, "AND p.numero_cliente = s.numero_cliente ");
	
	$PREPARE selClientes FROM $sql;
	
	$DECLARE curClientes CURSOR WITH HOLD FOR selClientes;

   /******** Cursor LECTURAS HISTO  ****************/
   $PREPARE selLecturas FROM "SELECT h.numero_cliente, 
      h.corr_facturacion, 
      h.fecha_lectura +1, 
      h.tipo_lectura, 
      h.lectura_facturac, 
      h.lectura_terreno, 
      h.numero_medidor, 
      h.marca_medidor,
      h.clave_lectura, 
      t1.cod_smile src_deta, 
      t2.cod_smile src_code, 
      t3.cod_smile tip_lectu,
      t4.cod_smile tip_anom,
      t5.cod_smile source_type, 
      h2.lectu_factu_reac
      FROM hislec h, sm_transforma t1, 
      sm_transforma t2, sm_transforma t3, OUTER sm_transforma t4, 
      sm_transforma t5, OUTER hislec_reac h2
      WHERE h.numero_cliente = ?
      AND h.tipo_lectura = 7
      AND h.fecha_lectura = (SELECT max(hl2.fecha_lectura) FROM hislec hl2
		WHERE hl2.numero_cliente = h.numero_cliente
		AND hl2.tipo_lectura = 7
		AND hl2.fecha_lectura <= ?)
      AND t1.clave = 'SRCDETA'
      AND t1.cod_mac_numerico = h.tipo_lectura
      AND t2.clave = 'SRCCODE'
      AND t2.cod_mac_numerico = h.tipo_lectura
      AND t3.clave = 'TIPLECTU'
      AND t3.cod_mac_numerico = h.tipo_lectura
      AND t4.clave = 'ANOMLECTU'
      AND t4.cod_mac_alfa = h.clave_lectura
      AND t5.clave = 'SRCTYPE'
      AND t5.cod_mac_numerico = h.tipo_lectura      
      AND h2.numero_cliente = h.numero_cliente
      AND h2.corr_facturacion = h.corr_facturacion
      AND h2.tipo_lectura = h.tipo_lectura
      AND h2.fecha_lectura = h.fecha_lectura
      ORDER BY 3, 4 ASC ";   
	
	$DECLARE curLecturas CURSOR WITH HOLD FOR selLecturas;
   
/*------------*/
   $PREPARE selLecturasCM FROM "SELECT h.numero_cliente, 
      h.corr_facturacion,
      CASE
		WHEN h.tipo_lectura = 6 THEN h.fecha_lectura + 1
		ELSE h.fecha_lectura
      END, 
      h.tipo_lectura, 
      h.lectura_facturac, 
      h.lectura_terreno, 
      h.numero_medidor, 
      h.marca_medidor,
      h.clave_lectura, 
      t1.cod_smile src_deta, 
      t2.cod_smile src_code, 
      t3.cod_smile tip_lectu,
      t4.cod_smile tip_anom,
      t5.cod_smile source_type, 
      h2.lectu_factu_reac
      FROM hislec h, sm_transforma t1, 
      sm_transforma t2, sm_transforma t3, OUTER sm_transforma t4, 
      sm_transforma t5, OUTER hislec_reac h2
      WHERE h.numero_cliente = ?
      AND h.tipo_lectura IN (5, 6)
      AND h.fecha_lectura = (SELECT max(hl2.fecha_lectura) FROM hislec hl2
		WHERE hl2.numero_cliente = h.numero_cliente
		AND hl2.tipo_lectura IN (5, 6)
		AND hl2.fecha_lectura <= ?)
      AND t1.clave = 'SRCDETA'
      AND t1.cod_mac_numerico = h.tipo_lectura
      AND t2.clave = 'SRCCODE'
      AND t2.cod_mac_numerico = h.tipo_lectura
      AND t3.clave = 'TIPLECTU'
      AND t3.cod_mac_numerico = h.tipo_lectura
      AND t4.clave = 'ANOMLECTU'
      AND t4.cod_mac_alfa = h.clave_lectura
      AND t5.clave = 'SRCTYPE'
      AND t5.cod_mac_numerico = h.tipo_lectura      
      AND h2.numero_cliente = h.numero_cliente
      AND h2.corr_facturacion = h.corr_facturacion
      AND h2.tipo_lectura = h.tipo_lectura
      AND h2.fecha_lectura = h.fecha_lectura
      ORDER BY 3, 4 ASC ";   
	
	$DECLARE curLecturasCM CURSOR WITH HOLD FOR selLecturasCM;



/*----------*/
   $PREPARE selLecturasRT FROM "SELECT h.numero_cliente, 
      h.corr_facturacion, 
      h.fecha_lectura, 
      h.tipo_lectura, 
      h.lectura_facturac, 
      h.lectura_terreno, 
      h.numero_medidor, 
      h.marca_medidor,
      h.clave_lectura, 
      t1.cod_smile src_deta, 
      t2.cod_smile src_code, 
      t3.cod_smile tip_lectu,
      t4.cod_smile tip_anom,
      t5.cod_smile source_type, 
      h2.lectu_factu_reac
      FROM hislec h, sm_transforma t1, 
      sm_transforma t2, sm_transforma t3, OUTER sm_transforma t4, 
      sm_transforma t5, OUTER hislec_reac h2
      WHERE h.numero_cliente = ?
      AND h.tipo_lectura = 5
      AND h.fecha_lectura = (SELECT max(hl2.fecha_lectura) FROM hislec hl2
		WHERE hl2.numero_cliente = h.numero_cliente
		AND hl2.tipo_lectura = 5
		AND hl2.fecha_lectura <= ?)
      AND t1.clave = 'SRCDETA'
      AND t1.cod_mac_numerico = h.tipo_lectura
      AND t2.clave = 'SRCCODE'
      AND t2.cod_mac_numerico = h.tipo_lectura
      AND t3.clave = 'TIPLECTU'
      AND t3.cod_mac_numerico = h.tipo_lectura
      AND t4.clave = 'ANOMLECTU'
      AND t4.cod_mac_alfa = h.clave_lectura
      AND t5.clave = 'SRCTYPE'
      AND t5.cod_mac_numerico = h.tipo_lectura      
      AND h2.numero_cliente = h.numero_cliente
      AND h2.corr_facturacion = h.corr_facturacion
      AND h2.tipo_lectura = h.tipo_lectura
      AND h2.fecha_lectura = h.fecha_lectura
      ORDER BY 3, 4 ASC ";   
	
	$DECLARE curLecturasRT CURSOR WITH HOLD FOR selLecturasRT;

   
	/******** Sel Modelo Medidor *********/
	strcpy(sql, "SELECT FIRST 1 m.modelo_medidor, NVL(m.tipo_medidor, 'A'), m.estado ");
	strcat(sql, "FROM medid m ");
	strcat(sql, "WHERE m.marca_medidor = ? ");
	strcat(sql, "AND m.numero_medidor = ? ");
	strcat(sql, "AND m.numero_cliente = ? ");
   
   $PREPARE selModMed FROM $sql;
   
	/******** Sel Hislec Rectificado *********/
	strcpy(sql, "SELECT FIRST 1 h1.lectura_rectif, h1.consumo_rectif, h1.refacturado ");
	strcat(sql, "FROM hislec_refac h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.corr_facturacion = ? ");
	strcat(sql, "AND h1.tipo_lectura = ? ");
	strcat(sql, "AND h1.corr_hislec_refac = (SELECT MAX(h2.corr_hislec_refac) ");
	strcat(sql, "	FROM hislec_refac h2 ");
	strcat(sql, " 	WHERE h2.numero_cliente = h1.numero_cliente ");
	strcat(sql, "   AND h2.corr_facturacion = h1.corr_facturacion ");
	strcat(sql, "   AND h2.tipo_lectura = h1.tipo_lectura ");
	strcat(sql, "   AND h2.refacturado != 'A' ) ");
   
	$PREPARE selHislecRefac FROM $sql;

	/******** Sel Hislec Reac *********/   
	strcpy(sql, "SELECT DISTINCT lectu_factu_reac, ");
	strcat(sql, "lectu_terreno_reac, ");
	strcat(sql, "consumo_reac ");
	strcat(sql, "FROM hislec_reac ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND corr_facturacion = ? ");
	strcat(sql, "AND tipo_lectura = ? ");

   $PREPARE selHislecReac FROM $sql;

	/******** Sel Hislec Reac Rectificado *********/
	strcpy(sql, "SELECT FIRST 1 h1.lectu_rectif_reac, h1.consu_rectif_reac ");
	strcat(sql, "FROM hislec_refac_reac h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.corr_facturacion = ? ");
	strcat(sql, "AND h1.tipo_lectura = ? ");
	strcat(sql, "AND h1.corr_hislec_refac = (SELECT MAX(h2.corr_hislec_refac) ");
	strcat(sql, "	FROM hislec_refac_reac h2 ");
	strcat(sql, " 	WHERE h2.numero_cliente = h1.numero_cliente ");
	strcat(sql, "   AND h2.corr_facturacion = h1.corr_facturacion ");
	strcat(sql, "   AND h2.tipo_lectura = h1.tipo_lectura )" );
   
	$PREPARE selHislecReacRefac FROM $sql;	

	/******** Select Path de Archivos ****************/
	strcpy(sql, "SELECT valor_alf ");
	strcat(sql, "FROM tabla ");
	strcat(sql, "WHERE nomtabla = 'PATH' ");
	strcat(sql, "AND codigo = ? ");
	strcat(sql, "AND sucursal = '0000' ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND ( fecha_desactivac >= TODAY OR fecha_desactivac IS NULL ) ");

	$PREPARE selRutaPlanos FROM $sql;

	/* Tipo lectura  */
	$PREPARE selTipoLectu FROM "SELECT tipo_lectura FROM hislec
		WHERE numero_cliente = ?
		AND corr_facturacion = ? 
		AND tipo_lectura NOT IN (5, 6) ";
		
	/* Fecha de Baja */
	$PREPARE selBaja FROM "SELECT MAX(DATE(fecha_modif)) FROM modif
	WHERE numero_cliente = ?
	AND codigo_modif = '58' ";

	/* Actualiza ot_ana */
	$PREPARE updOT FROM "UPDATE ot_anagrafica SET
	fecha_envia_misura = TODAY
	WHERE numero_cliente = ?
	AND fecha_novedad = ?
	AND tipo_ot = ?
	AND fecha_unlock IS NULL ";

		
}

void FechaGeneracionFormateada( Fecha )
char *Fecha;
{
	$char fmtFecha[20];
	
	memset(fmtFecha,'\0',sizeof(fmtFecha));
	
	$EXECUTE selFechaActualFmt INTO :fmtFecha;
	
	strcpy(Fecha, fmtFecha);
	
}

void RutaArchivos( ruta, clave )
$char ruta[100];
$char clave[7];
{

	$EXECUTE selRutaPlanos INTO :ruta using :clave;

    if ( SQLCODE != 0 ){
        printf("ERROR.\nSe produjo un error al tratar de recuperar el path destino del archivo.\n");
        exit(1);
    }

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

short LeoCliente(reg)
$ClsCliente	*reg;
{
	
   InicializaCliente(reg);
   
   $FETCH curClientes INTO 
		:reg->lNroCliente,
		:reg->lFechaNovedad, 
		:reg->sTipoOt,
		:reg->iCorrFacturacion,
		:reg->iEstadoCliente,
		:reg->lFechaMoveIn;
   
    if ( SQLCODE != 0 ){
        return 0;
    }

	if(reg->iEstadoCliente != 0){
		$EXECUTE selBaja INTO :reg->lFechaBaja;
		
		if(SQLCODE != 0){
			printf("Cliente %ld No se encontró fecha de Baja. Se reemplaza con Fecha Evento.\n", reg->lNroCliente);
			reg->lFechaBaja = reg->lFechaNovedad;
		}
	}
	
   return 1;
}

void InicializaCliente(reg)
$ClsCliente *reg;
{
	
	rsetnull(CLONGTYPE, (char *) &(reg->lNroCliente));
	rsetnull(CLONGTYPE, (char *) &(reg->lFechaNovedad));
	memset(reg->sTipoOt, '\0', sizeof(reg->sTipoOt));
	rsetnull(CINTTYPE, (char *) &(reg->iCorrFacturacion));
	rsetnull(CINTTYPE, (char *) &(reg->iEstadoCliente));
	rsetnull(CLONGTYPE, (char *) &(reg->lFechaMoveIn));
	rsetnull(CLONGTYPE, (char *) &(reg->lFechaBaja));
	
}


short LeoLecturas(regLec, lFechaMoveIn, sTipoOt)
$ClsLectura *regLec;
long	lFechaMoveIn;
char	sTipoOt[3];
{
   $double dLecturaActiRectif;
   $double dConsumoActiRectif;
   $double dLecturaReacRectif;
   $double dConsumoReacRectif;
   $char   sRefacturado[2];
   char		sAuxiliar[21];
   
   memset(sRefacturado, '\0', sizeof(sRefacturado));
   memset(sAuxiliar, '\0', sizeof(sAuxiliar));

	InicializaLectura(regLec);
   
	if(strcmp(sTipoOt, "SS")==0){
		$FETCH curLecturas INTO
		  :regLec->numero_cliente,
		  :regLec->corr_facturacion,
		  :regLec->fecha_lectura,       
		  :regLec->tipo_lectura,
		  :regLec->lectura_facturac,
		  :regLec->lectura_terreno,
		  :regLec->numero_medidor,
		  :regLec->marca_medidor,
		  :regLec->clave_lectura,
		  :regLec->src_deta,
		  :regLec->src_code,
		  :regLec->tip_lectu,
		  :regLec->tip_anom,
		  :regLec->src_type,
		  :regLec->lectura_facturac_reac;   
		
	}else if(strcmp(sTipoOt, "SC")==0){
		$FETCH curLecturasCM INTO
		  :regLec->numero_cliente,
		  :regLec->corr_facturacion,
		  :regLec->fecha_lectura,       
		  :regLec->tipo_lectura,
		  :regLec->lectura_facturac,
		  :regLec->lectura_terreno,
		  :regLec->numero_medidor,
		  :regLec->marca_medidor,
		  :regLec->clave_lectura,
		  :regLec->src_deta,
		  :regLec->src_code,
		  :regLec->tip_lectu,
		  :regLec->tip_anom,
		  :regLec->src_type,
		  :regLec->lectura_facturac_reac;   
		
	}else{
		$FETCH curLecturasRT INTO
		  :regLec->numero_cliente,
		  :regLec->corr_facturacion,
		  :regLec->fecha_lectura,       
		  :regLec->tipo_lectura,
		  :regLec->lectura_facturac,
		  :regLec->lectura_terreno,
		  :regLec->numero_medidor,
		  :regLec->marca_medidor,
		  :regLec->clave_lectura,
		  :regLec->src_deta,
		  :regLec->src_code,
		  :regLec->tip_lectu,
		  :regLec->tip_anom,
		  :regLec->src_type,
		  :regLec->lectura_facturac_reac;   
		
	}
	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de Lecturas !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			

    alltrim(regLec->clave_lectura, ' ');
    alltrim(regLec->src_deta, ' ');
    alltrim(regLec->src_code, ' ');
    alltrim(regLec->tip_lectu, ' ');
    alltrim(regLec->src_type, ' ');
    alltrim(regLec->tip_anom, ' ');
    
    /* Marca Factura Migrada */
    /* Marca Factura Migrada */
    if(regLec->fecha_lectura > lFechaMoveIn){
		strcpy(regLec->flag_migrado, "S");
	}else{
		strcpy(regLec->flag_migrado, "N");
	}
    
    /* Columnizo el tipo de lectura */

    strcpy(sAuxiliar, strReplace(regLec->tip_lectu, "_", "|"));
    strcpy(regLec->tip_lectu, sAuxiliar);

    
    /* Buscar si existe el ultimo ajuste activo */
    $EXECUTE selHislecRefac 
      INTO :dLecturaActiRectif, :dConsumoActiRectif, :sRefacturado
      USING :regLec->numero_cliente, :regLec->corr_facturacion, :regLec->tipo_lectura;
      
    if(SQLCODE == 0){
       regLec->lectura_facturac = dLecturaActiRectif;
       if(sRefacturado[0]=='S'){
			strcpy(regLec->flag_consumo_pendiente, "N");
	   }else{
		    strcpy(regLec->flag_consumo_pendiente, "S");
	   }
    }else{
		strcpy(regLec->flag_consumo_pendiente, "N");
	}
      
    /* Buscar si existe el ultimo ajuste reactivo */
    if(!risnull(CDOUBLETYPE, (char *)&regLec->lectura_facturac_reac)){
       $EXECUTE selHislecReacRefac
         INTO :dLecturaReacRectif, :dConsumoReacRectif
         USING :regLec->numero_cliente, :regLec->corr_facturacion, :regLec->tipo_lectura;
         
       if(SQLCODE == 0){
          regLec->lectura_facturac_reac = dLecturaReacRectif;
       }
   }
               
	return 1;	
}

void InicializaLectura(regLec)
$ClsLectura	*regLec;
{

   rsetnull(CLONGTYPE, (char *) &(regLec->numero_cliente));
   rsetnull(CINTTYPE, (char *) &(regLec->corr_facturacion));
   rsetnull(CLONGTYPE, (char *) &(regLec->fecha_lectura));
   rsetnull(CINTTYPE, (char *) &(regLec->tipo_lectura));
   rsetnull(CDOUBLETYPE, (char *) &(regLec->lectura_facturac));
   rsetnull(CDOUBLETYPE, (char *) &(regLec->lectura_terreno));
	rsetnull(CLONGTYPE, (char *) &(regLec->numero_medidor));
   memset(regLec->marca_medidor, '\0', sizeof(regLec->marca_medidor));
   memset(regLec->clave_lectura, '\0', sizeof(regLec->clave_lectura));
   memset(regLec->src_deta, '\0', sizeof(regLec->src_deta));
   memset(regLec->src_code, '\0', sizeof(regLec->src_code));
   memset(regLec->tip_lectu, '\0', sizeof(regLec->tip_lectu));
   memset(regLec->tip_anom, '\0', sizeof(regLec->tip_anom));
   memset(regLec->src_type, '\0', sizeof(regLec->src_type));
   rsetnull(CDOUBLETYPE, (char *) &(regLec->lectura_facturac_reac));
   memset(regLec->flag_migrado, '\0', sizeof(regLec->flag_migrado));
   memset(regLec->flag_consumo_pendiente, '\0', sizeof(regLec->flag_consumo_pendiente));

}


void GenerarPlanoMisura(regLec, iFlag, iStatus, lFechaLR)
$ClsLectura		regLec;
int				iFlag;
int				iStatus; /* Estado del cliente*/
long			lFechaLR; /* Fecha supesta de lectura de baja */
{
	char	sLinea[1000];
	int   iRcv;	
	char  sFecha[20];

	memset(sLinea, '\0', sizeof(sLinea));
	memset(sFecha, '\0', sizeof(sFecha));

	rfmtdate(regLec.fecha_lectura, "dd/mm/yyyy 00:00:00", sFecha); 
   
   /* 1 podId */
   sprintf(sLinea, "AR103E%0.8ld|", regLec.numero_cliente);
   
   /* 2 manufacturer */
   sprintf(sLinea, "%s%s|", sLinea, regLec.marca_medidor);
   
   /* 3 model */
   strcat(sLinea, "|");
   
   /* 4 serialNumber */
   sprintf(sLinea, "%s%0.9ld|", sLinea, regLec.numero_medidor);
   
   /* 5 SourceType */
	if(iStatus == 0 ){
		sprintf(sLinea, "%s%s|", sLinea, regLec.src_type);
	}else if(regLec.tipo_lectura == 5 && regLec.fecha_lectura >= lFechaLR){
		strcat(sLinea, "CESSAZIONE|");
	}else{
		sprintf(sLinea, "%s%s|", sLinea, regLec.src_type);
	}
   
   /* 6 SourceDetail */
   sprintf(sLinea, "%s%s|", sLinea, regLec.src_deta);
   
   /* 7 SourceCode */
   sprintf(sLinea, "%s%s|", sLinea, regLec.src_code);
   
   /* 8 anomalyCode */
   if(strcmp(regLec.clave_lectura,"")!=0){
      if(strcmp(regLec.tip_anom, "NO_LECTURA")){
         sprintf(sLinea, "%s%s|", sLinea, regLec.clave_lectura);
      }else{
         strcat(sLinea, "|");
      }
   }else{
      strcat(sLinea, "|");
   }
   
   /* 9 anomalyReasonCode */
   if(strcmp(regLec.clave_lectura,"")!=0){
      if(strcmp(regLec.tip_anom, "LECTURA")){
         sprintf(sLinea, "%s%s|", sLinea, regLec.clave_lectura);
      }else{
         strcat(sLinea, "|");
      }
   }else{
      strcat(sLinea, "|");
   }
   
   /* 10 readingDate del Sistema */
   sprintf(sLinea, "%s%s|", sLinea, sFecha);
   
   /* 11 readingDate del Contatore */
   sprintf(sLinea, "%s%s|", sLinea, sFecha);
   
   /* 12 Note */
   strcat(sLinea, ";;;;;;;;|");
    
   /* 13 Matricola Letturista */
   strcat(sLinea, "*|");
   
   /* 14 Energia Attiva Prelevata */
	sprintf(sLinea, "%s%.0f|", sLinea, regLec.lectura_facturac);
   
   /* 15 Energia Reattiva (Q1) */
   if(!risnull(CDOUBLETYPE, (char *) &regLec.lectura_facturac_reac) && regLec.lectura_facturac_reac != -1){
      sprintf(sLinea, "%s%.0f|", sLinea, regLec.lectura_facturac_reac);
   }else{
      strcat(sLinea, "|");
   }
   
   /* 16 Energia Reattiva (Q4) */
   strcat(sLinea, "|");
   /* 17 Energia Attiva Immessa */
   strcat(sLinea, "|");
   /* 18 Energia Reattiva (Q2) */
   strcat(sLinea, "|");
   /* 19 Energia Reattiva (Q3) */
   strcat(sLinea, ";;|");
   
   /* 20 Energia Attiva Prelevata */
   strcat(sLinea, "|");
   /* 21 Energia Reattiva */
   strcat(sLinea, "|"); 
   /* 22 Picco di Energia Reattiva */
   strcat(sLinea, "|");
   /* 23 Potenza Attiva Prelevata */
   strcat(sLinea, "|");
   /* 24 Energia Attiva Immessa */
   strcat(sLinea, "|");
   /* 25 Potenza Attiva Immessa */
   strcat(sLinea, "|");
   /* 26 Energia Reattiva (Q2) */
   strcat(sLinea, "|");
   /* 27 Energia Reattiva (Q3) */
   strcat(sLinea, "|");
   /* 28 Energia Attiva Prelevata */
   strcat(sLinea, "|");
   /* 29 Energia Reattiva */
   strcat(sLinea, "|");
   /* 30 Picco di Energia Reattiva */
   strcat(sLinea, "|");
   /* 31 Potenza Attiva Prelevata */
   strcat(sLinea, "|");
   /* 32 Energia Attiva Immessa */
   strcat(sLinea, "|");
   /* 33 Potenza Attiva Immessa */
   strcat(sLinea, "|");
   /* 34 Energia Reattiva (Q2) */
   strcat(sLinea, "|");
   /* 35 Energia Reattiva (Q3) */
   strcat(sLinea, "|");

   /* 36 Energia Attiva Prelevata */
   sprintf(sLinea, "%s%.0f|", sLinea, regLec.lectura_facturac);

   /* 37 Energia Reattiva */
   if(!risnull(CDOUBLETYPE, (char *) &regLec.lectura_facturac_reac) && regLec.lectura_facturac_reac != -1){
      sprintf(sLinea, "%s%.0f|", sLinea, regLec.lectura_facturac_reac);
   }else{
      strcat(sLinea, "|");
   }
   
   /* 38 Picco di Energia Reattiva */
   strcat(sLinea, "|");
   /* 39 Potenza Attiva Prelevata */
   strcat(sLinea, "|");
   /* 40 Energia Attiva Immessa */
   strcat(sLinea, "|");
   /* 41 Potenza Attiva Immessa */
   strcat(sLinea, "|");
   /* 42 Energia Reattiva (Q2) */
   strcat(sLinea, "|");
   /* 43 Energia Reattiva (Q3) */
   strcat(sLinea, "|");
   

	strcat(sLinea, "\r\n");

	iRcv=fprintf(pFileMisura, sLinea);
	
   if(iRcv<0){
      printf("Error al grabar Misura. iFalg %d\n",iFlag);
      exit(1);
   }
}

void GenerarPlanoAdjunto(regLec, iFlag, iStatus, lFechaLR)
$ClsLectura		regLec;
int				iFlag;
int				iStatus; /* Estado del cliente*/
long			lFechaLR; /* Fecha supesta de lectura de baja */
{
	char	sLinea[1000];
	int   iRcv;	
	char  sFecha[20];

	memset(sLinea, '\0', sizeof(sLinea));
	memset(sFecha, '\0', sizeof(sFecha));
   
	rfmtdate(regLec.fecha_lectura, "dd/mm/yyyy", sFecha);


	/* Eneltel */
	sprintf(sLinea, "%0.9ld|", regLec.numero_cliente);

	/* POD */
	sprintf(sLinea, "%sAR103E%0.8ld|", sLinea, regLec.numero_cliente);

	/* Fecha lectura */
	sprintf(sLinea, "%s%s|", sLinea, sFecha);

	/* Tipo lectura */
	if(iStatus == 0 ){
		sprintf(sLinea, "%s%s|", sLinea, regLec.tip_lectu);
	}else if(regLec.tipo_lectura == 5 && regLec.fecha_lectura >= lFechaLR){
		strcat(sLinea, "C|6|C|");
	}else{
		sprintf(sLinea, "%s%s|", sLinea, regLec.tip_lectu);
	}

	/* Flag SAP */
	sprintf(sLinea, "%s%s|", sLinea, regLec.flag_migrado);

	/* Energia Pendiente */
	sprintf(sLinea, "%s%s|", sLinea, regLec.flag_consumo_pendiente);

	strcat(sLinea, "\n");

	if(iFlag==0){
		iRcv=fprintf(pFileMisuraAdj, sLinea);
	}else{
		iRcv=fprintf(pFileMisuraAdjPend, sLinea);
	}

	if(iRcv < 0){
		printf("Error al escribir MisuraAdj. iFlag %d\n", iFlag);
		exit(1);
	}	
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

/*
short EnviarMail( Adjunto1, Adjunto2)
char *Adjunto1;
char *Adjunto2;
{
    char 	*sClave[] = {SYN_CLAVE};
    char 	*sAdjunto[3]; 
    int		iRcv;
    
    sAdjunto[0] = Adjunto1;
    sAdjunto[1] = NULL;
    sAdjunto[2] = NULL;

	iRcv = synmail(sClave[0], sMensMail, NULL, sAdjunto);
	
	if(iRcv != SM_OK){
		return 0;
	}
	
    return 1;
}

void  ArmaMensajeMail(argv)
char	* argv[];
{
$char	FechaActual[11];

	
	memset(FechaActual,'\0', sizeof(FechaActual));
	$EXECUTE selFechaActual INTO :FechaActual;
	
	memset(sMensMail,'\0', sizeof(sMensMail));
	sprintf( sMensMail, "Fecha de Proceso: %s<br>", FechaActual );
	if(strcmp(argv[1],"M")==0){
		sprintf( sMensMail, "%sNovedades Monetarias<br>", sMensMail );		
	}else{
		sprintf( sMensMail, "%sNovedades No Monetarias<br>", sMensMail );		
	}
	if(strcmp(argv[2],"R")==0){
		sprintf( sMensMail, "%sRegeneracion<br>", sMensMail );
		sprintf(sMensMail,"%sOficina:%s<br>",sMensMail, argv[3]);
		sprintf(sMensMail,"%sF.Desde:%s|F.Hasta:%s<br>",sMensMail, argv[4], argv[5]);
	}else{
		sprintf( sMensMail, "%sGeneracion<br>", sMensMail );
	}		
	
}
*/


char *strReplace(sCadena, cFind, cRemp)
char *sCadena;
char cFind[2];
char cRemp[2];
{
	char sNvaCadena[1000];
	int lLargo;
	int lPos;

	memset(sNvaCadena, '\0', sizeof(sNvaCadena));
	
	lLargo=strlen(sCadena);

    if (lLargo == 0)
    	return sCadena;

	for(lPos=0; lPos<lLargo; lPos++){

       if (sCadena[lPos] != cFind[0]) {
       	sNvaCadena[lPos]=sCadena[lPos];
       }else{
	       if(strcmp(cRemp, "")!=0){
	       		sNvaCadena[lPos]=cRemp[0];  
	       }else {
	            sNvaCadena[lPos]=' ';   
	       }
       }
	}

	return sNvaCadena;
}


