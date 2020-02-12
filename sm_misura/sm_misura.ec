/*********************************************************************************
    Proyecto: Migracion al sistema SALES-FORCES
    Aplicacion: sfc_device
    
	Fecha : 03/01/2018

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

$include "sm_misura.h";

/* Variables Globales */
int   giTipoCorrida;
int   gsArchivoGenera;

FILE	*pFileMisura;
FILE	*pFileMisuraAdj;

char	sArchMisuraUnx[100];
char	sArchMisuraAux[100];
char	sArchMisuraDos[100];
char	sSoloArchivoMisura[100];

char	sArchMisuraAdjUnx[100];
char	sArchMisuraAdjAux[100];
char	sArchMisuraAdjDos[100];
char	sSoloArchivoMisuraAdj[100];

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
$ClsLectura	regLectura;
$long glFechaDesde;
$long glFechaHasta;

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
$long    lFecha4Y;

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
   $EXECUTE selFechaInicio INTO :lFecha4Y;
   
	if(!AbreArchivos(iIndexFile)){
		exit(1);	
	}
   iIndexFile++;
	cantProcesada=0;
	cantPreexistente=0;
	iContaLog=0;
	
	/*********************************************
				AREA CURSOR PPAL
	**********************************************/

   iFilasFile=0;
   
   $OPEN curClientes;

   while(LeoCliente(&lNroCliente, &lFechaPivote)){

      $OPEN curLecturas USING :lNroCliente, :lFecha4Y;
   
   	while(LeoLecturas(&regLectura)){
         GenerarPlanoMisura(regLectura);
         
         GenerarPlanoAdjunto(regLectura);
         
         iFilasFile++;      
      }
   	$CLOSE curLecturas;
      cantProcesada++;
      
      if(iFilasFile > 500000){
         CerrarArchivos();
         MoverArchivos();
         printf("Clientes Procesados hasta el momento: %ld\n", cantProcesada);
      	if(!AbreArchivos(iIndexFile)){
      		exit(1);	
      	}
         iIndexFile++;
         iFilasFile=0;         
      }
   }
   			
   $CLOSE curClientes;      

	CerrarArchivos();

	MoverArchivos();

	$CLOSE DATABASE;

	$DISCONNECT CURRENT;


	/* ********************************************
				FIN AREA DE PROCESO
	********************************************* */

	printf("==============================================\n");
	printf("SMILE :) - MISURA\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Clientes Procesados :       %ld \n", cantProcesada);
   printf("Archivos Generados por tipo:%ld \n", iIndexFile);
	printf("==============================================\n");
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));						

	hora = time(&hora);
	printf("\nHora de finalizacion del proceso : %s\n", ctime(&hora));

	if(iContaLog>0){
		printf("Existen registros en el archivo de log.\nFavor de revisar.\n");	
	}
	printf("Fin del proceso OK\n");	

	exit(0);
}	

short AnalizarParametros(argc, argv)
int		argc;
char	* argv[];
{
   char  sFechaDesde[11];
   char  sFechaHasta[11];
   
   memset(sFechaDesde, '\0', sizeof(sFechaDesde));
   memset(sFechaHasta, '\0', sizeof(sFechaHasta));

   memset(gsDesdeFmt, '\0', sizeof(gsDesdeFmt));
   memset(gsHastaFmt, '\0', sizeof(gsHastaFmt));
   
	if(argc < 3 || argc > 5 ){
		MensajeParametros();
		return 0;
	}
   giTipoCorrida=atoi(argv[2]);
	
   if(argc==5){
      giTipoCorrida=3;/* Modo Delta */
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
      printf("	<Fecha Desde (Opcional)> dd/mm/aaaa.\n");
      printf("	<Fecha Hasta (Opcional)> dd/mm/aaaa.\n");
      
}

short AbreArchivos(iIndex)
int   iIndex;
{
   char  sTitulos[10000];
   $char sFecha[9];
   int   iRcv;
   
   memset(sTitulos, '\0', sizeof(sTitulos));
	
	memset(sArchMisuraUnx,'\0',sizeof(sArchMisuraUnx));
	memset(sArchMisuraAux,'\0',sizeof(sArchMisuraAux));
   memset(sArchMisuraDos,'\0',sizeof(sArchMisuraDos));
	memset(sSoloArchivoMisura,'\0',sizeof(sSoloArchivoMisura));
	
	memset(sArchMisuraAdjUnx,'\0',sizeof(sArchMisuraAdjUnx));
	memset(sArchMisuraAdjAux,'\0',sizeof(sArchMisuraAdjAux));
   memset(sArchMisuraAdjDos,'\0',sizeof(sArchMisuraAdjDos));
	memset(sSoloArchivoMisuraAdj,'\0',sizeof(sSoloArchivoMisuraAdj));

   memset(sFecha,'\0',sizeof(sFecha));
	memset(sPathSalida,'\0',sizeof(sPathSalida));

   FechaGeneracionFormateada(sFecha);
   
	RutaArchivos( sPathSalida, "SAPISU" );
	alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SAPCPY" );
   alltrim(sPathCopia,' ');
   strcat(sPathCopia, "SMILE/");

	sprintf( sArchMisuraUnx  , "%sLEITURA_T1.unx", sPathSalida );
   sprintf( sArchMisuraAux  , "%sLEITURA_T1.aux", sPathSalida );
   sprintf( sArchMisuraDos  , "%sLEITURA_T1_%s_%d.txt", sPathSalida, sFecha, iIndex);

	sprintf( sArchMisuraAdjUnx  , "%sADJUNTO_LEITURA_T1.unx", sPathSalida );
   sprintf( sArchMisuraAdjAux  , "%sADJUNTO_LEITURA_T1.aux", sPathSalida );
   sprintf( sArchMisuraAdjDos  , "%sADJUNTO_LEITURA_T1_%s_%d.txt", sPathSalida, sFecha, iIndex);


	pFileMisura=fopen( sArchMisuraUnx, "w" );
	if( !pFileMisura ){
		printf("ERROR al abrir archivo %s.\n", sArchMisuraUnx );
		return 0;
	}

   /* ---------------- */
   
	pFileMisuraAdj=fopen( sArchMisuraAdjUnx, "w" );
	if( !pFileMisuraAdj ){
		printf("ERROR al abrir archivo %s.\n", sArchMisuraAdjUnx );
		return 0;
	}

	return 1;	
}

void CerrarArchivos(void)
{
	fclose(pFileMisura);
	fclose(pFileMisuraAdj);

}

void MoverArchivos(void){
char	sCommand[10000];
int	iRcv, i;
	
   sprintf(sCommand, "iconv -f WINDOWS-1252 -t UTF-8 %s > %s ", sArchMisuraUnx, sArchMisuraDos);
   iRcv=system(sCommand);
   
	sprintf(sCommand, "chmod 777 %s", sArchMisuraDos);
	iRcv=system(sCommand);


	sprintf(sCommand, "mv %s %s", sArchMisuraDos, sPathCopia);
	iRcv=system(sCommand);

   if(iRcv >= 0){        
      sprintf(sCommand, "rm %s", sArchMisuraUnx);
      iRcv=system(sCommand);
   }         
   
   /* ------------- */
   
   sprintf(sCommand, "iconv -f WINDOWS-1252 -t UTF-8 %s > %s ", sArchMisuraAdjUnx, sArchMisuraAdjDos);
   iRcv=system(sCommand);
   
	sprintf(sCommand, "chmod 777 %s", sArchMisuraAdjDos);
	iRcv=system(sCommand);

	sprintf(sCommand, "mv %s %s", sArchMisuraAdjDos, sPathCopia);
	iRcv=system(sCommand);

   if(iRcv >= 0){        
      sprintf(sCommand, "rm %s", sArchMisuraAdjUnx);
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

   /* Fecha Inicio Lecturas */
   $PREPARE selFechaInicio FROM "SELECT TODAY - 1460 FROM dual ";
   
	/******** Cursor CLIENTES  ****************/	
	strcpy(sql, "SELECT c.numero_cliente, s.fecha_pivote FROM cliente c, sap_regi_cliente s ");
if(giTipoCorrida==1){
   strcat(sql, ", migra_activos m ");
}   
	strcat(sql, "WHERE c.estado_cliente = 0 ");
   strcat(sql, "AND c.tipo_sum NOT IN (5, 6) ");
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cm.fecha_activacion < TODAY ");
	strcat(sql, "AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");	
   strcat(sql, "AND s.numero_cliente = c.numero_cliente ");
if(giTipoCorrida==1){
   strcat(sql, "AND m.numero_cliente = c.numero_cliente ");
}   
   
	$PREPARE selClientes FROM $sql;
	
	$DECLARE curClientes CURSOR WITH HOLD FOR selClientes;

   /******** Cursor LECTURAS  ****************/
   $PREPARE selLecturas FROM "SELECT h.numero_cliente, 
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
      AND h.fecha_lectura >= ?
      AND h.tipo_lectura != 8
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
      ORDER BY h.fecha_lectura, h.tipo_lectura ASC ";   
	
	$DECLARE curLecturas CURSOR WITH HOLD FOR selLecturas;
   
	/******** Sel Modelo Medidor *********/
/*      
	strcpy(sql, "SELECT me.mod_codigo, NVL(mo.tipo_medidor, 'A') FROM medidor me, modelo mo ");
	strcat(sql, "WHERE me.mar_codigo = ? ");
	strcat(sql, "AND me.med_numero = ? ");
	strcat(sql, "AND me.numero_cliente = ? ");
	strcat(sql, "AND mo.mar_codigo = me.mar_codigo ");
	strcat(sql, "AND mo.mod_codigo = me.mod_codigo ");
*/
	strcpy(sql, "SELECT FIRST 1 m.modelo_medidor, NVL(m.tipo_medidor, 'A'), m.estado ");
	strcat(sql, "FROM medid m ");
	strcat(sql, "WHERE m.marca_medidor = ? ");
	strcat(sql, "AND m.numero_medidor = ? ");
	strcat(sql, "AND m.numero_cliente = ? ");
   
   $PREPARE selModMed FROM $sql;
   
	/******** Sel Hislec Rectificado *********/
	strcpy(sql, "SELECT FIRST 1 h1.lectura_rectif, h1.consumo_rectif ");
	strcat(sql, "FROM hislec_refac h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.corr_facturacion = ? ");
	strcat(sql, "AND h1.tipo_lectura = ? ");
	strcat(sql, "AND h1.corr_hislec_refac = (SELECT MAX(h2.corr_hislec_refac) ");
	strcat(sql, "	FROM hislec_refac h2 ");
	strcat(sql, " 	WHERE h2.numero_cliente = h1.numero_cliente ");
	strcat(sql, "   AND h2.corr_facturacion = h1.corr_facturacion ");
	strcat(sql, "   AND h2.tipo_lectura = h1.tipo_lectura) ");
   
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


}

void FechaGeneracionFormateada( Fecha )
char *Fecha;
{
	$char fmtFecha[9];
	
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

short LeoCliente(lNroCliente, lFechaPivote)
$long *lNroCliente;
$long *lFechaPivote;
{
   $long nroCliente;
   $long lFecha;
   
   $FETCH curClientes INTO :nroCliente, :lFecha;
   
    if ( SQLCODE != 0 ){
        return 0;
    }
   
   *lNroCliente = nroCliente;
   *lFechaPivote = lFecha;

   return 1;
}


short LeoLecturas(regLec)
$ClsLectura *regLec;
{
   $double dLecturaActiRectif;
   $double dConsumoActiRectif;
   $double dLecturaReacRectif;
   $double dConsumoReacRectif;

	InicializaLectura(regLec);
   
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
    
    /* Buscar si existe el ultimo ajuste activo */
    $EXECUTE selHislecRefac 
      INTO :dLecturaActiRectif, :dConsumoActiRectif
      USING :regLec->numero_cliente, :regLec->corr_facturacion, :regLec->tipo_lectura;
      
    if(SQLCODE == 0){
       regLec->lectura_facturac = dLecturaActiRectif;
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

}


void GenerarPlanoMisura(regLec)
$ClsLectura		regLec;
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
   sprintf(sLinea, "%s%s|", sLinea, regLec.src_type);
   
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
   if(!risnull(CDOUBLETYPE, (char *) &regLec.lectura_facturac_reac)){
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
   if(!risnull(CDOUBLETYPE, (char *) &regLec.lectura_facturac_reac)){
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
   

	strcat(sLinea, "\n");
	
   iRcv=fprintf(pFileMisura, sLinea);
   if(iRcv<0){
      printf("Error al grabar Misura\n");
      exit(1);
   }
}

void GenerarPlanoAdjunto(regLec)
$ClsLectura		regLec;
{
	char	sLinea[1000];
   int   iRcv;	
   char  sFecha[20];
   
	memset(sLinea, '\0', sizeof(sLinea));
   memset(sFecha, '\0', sizeof(sFecha));
   
   rfmtdate(regLec.fecha_lectura, "dd/mm/yyyy 00:00:00", sFecha);
	

   /* Eneltel */
   sprintf(sLinea, "%0.8ld|", regLec.numero_cliente);
   
   /* POD */
   sprintf(sLinea, "%sAR103E%0.8ld|", sLinea, regLec.numero_cliente);
   
   /* Fecha lectura */
   sprintf(sLinea, "%s%s|", sLinea, sFecha);
   
   /* Tipo lectura */
   sprintf(sLinea, "%s%s|", sLinea, regLec.tip_lectu);

	strcat(sLinea, "\n");
   	
	iRcv=fprintf(pFileMisuraAdj, sLinea);

   if(iRcv < 0){
      printf("Error al escribir MisuraAdj\n");
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


static char *strReplace(sCadena, cFind, cRemp)
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


