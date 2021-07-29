/***********************************************************************************
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
char	sArchMisuraDos[100];
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
	
	/*********************************************
				AREA CURSOR ACTUAL
	**********************************************/	
	iIndexFile=1;
	for(iPlan=41; iPlan <= 80; iPlan++){
		if(!AbreArchivosActual(iPlan, iIndexFile)){
			exit(1);	
		}
		iCantidadArchivos++;
		iIndexFile++;
		iFilasFile=0;

		/*$OPEN curClientes USING :iPlan;*/
		$OPEN curClientes USING :iPlan, :iPlan, :lFecha4Y;

		rsetnull(CLONGTYPE, (char *) &(lNroCliente));
		rsetnull(CLONGTYPE, (char *) &(lFechaPivote));
		rsetnull(CLONGTYPE, (char *) &(lFechaMoveIn));
		rsetnull(CLONGTYPE, (char *) &(iCorrFacturacion));
		rsetnull(CLONGTYPE, (char *) &(iTipoLectuActual));
		rsetnull(CINTTYPE, (char *) &(iEstadoCliente));
		
		while(LeoCliente(&lNroCliente, &lFechaPivote, &lFechaMoveIn, &iCorrFacturacion, &iEstadoCliente)){

			/*$OPEN curLecturasAct USING :lNroCliente, :iCorrFacturacion;*/

			if(LeoLecturasAct(lNroCliente, iCorrFacturacion, &regLectura, lFechaMoveIn)){
				
				if(regLectura.tipo_lectura == 8){
					if(LeoLecturaPend(lNroCliente, iCorrFacturacion, &regLectuPend)){
						if(regLectuPend.lectura_facturac >= 0){
							GenerarPlanoMisura(regLectuPend, 1);
							GenerarPlanoAdjunto(regLectuPend, 1);

							iCantLecturasPendientes++;
						}else{
							printf("Cliente %ld lectura 8 con pendiente sin valor en lecturas\n",lNroCliente);												
						}
					}else{
						printf("Cliente %ld con lectura 8 sin pendiente\n",lNroCliente);											
					}
				}else{
					GenerarPlanoMisura(regLectura, 0);
					GenerarPlanoAdjunto(regLectura, 0);

					iFilasFile++; 
					iCantLecturasActuales++;
				}
			}
			/*$CLOSE curLecturasAct;*/
			cantProcesada++;
		  
			if(iFilasFile > 500000){
				CerrarArchivos();
				fclose(pFileMisuraPend);
				fclose(pFileMisuraAdjPend);
				MoverArchivos(1);
				printf("Clientes - Lectura Actual Procesados hasta el momento: %ld\n", cantProcesada);
				if(!AbreArchivosActual(iPlan, iIndexFile)){
					exit(1);	
				}
				iIndexFile++;
				iFilasFile=0;         
				iCantidadArchivos++;
			}
		}
				
		$CLOSE curClientes;      

		CerrarArchivos();
		fclose(pFileMisuraPend);
		fclose(pFileMisuraAdjPend);
		MoverArchivos(1);
		
		iIndexFile=1;
				
	}  
	
	
	/*********************************************
				AREA CURSOR HISTORICO
	**********************************************/
	cantProcesada=0;
	iIndexFile=1;
	
	for(iPlan=41; iPlan <= 80; iPlan++){
		if(!AbreArchivos(iPlan, iIndexFile)){
			exit(1);	
		}
	   iIndexFile++;
	   iCantidadArchivos++;
	   
	   iFilasFile=0;
	   
	   /*$OPEN curClientes USING :iPlan;*/
	   $OPEN curClientes USING :iPlan, :iPlan, :lFecha4Y;

		rsetnull(CLONGTYPE, (char *) &(lNroCliente));
		rsetnull(CLONGTYPE, (char *) &(lFechaPivote));
		rsetnull(CLONGTYPE, (char *) &(lFechaMoveIn));
		rsetnull(CLONGTYPE, (char *) &(iCorrFacturacion));
		rsetnull(CLONGTYPE, (char *) &(iTipoLectuActual));
		rsetnull(CINTTYPE, (char *) &(iEstadoCliente));

	   while(LeoCliente(&lNroCliente, &lFechaPivote, &lFechaMoveIn, &iCorrFacturacion, &iEstadoCliente)){
		  iCorrFactuActual=iCorrFacturacion;
		  iCorrFacturacion=getCorrelativoLectu(lNroCliente, iCorrFacturacion);
		  iCorrFactuFutura=iCorrFactuActual + 1;
		  
		  if(iCorrFacturacion >= 0){
			$OPEN curLecturas USING :lNroCliente, :lFecha4Y, :iCorrFacturacion, :lNroCliente, :iCorrFactuActual;
	   
			while(LeoLecturas(&regLectura, lFechaMoveIn)){
				GenerarPlanoMisura(regLectura, 0);
				GenerarPlanoAdjunto(regLectura, 0);
			 
				iFilasFile++;      
			}
			$CLOSE curLecturas;
			cantProcesada++;
		  
			if(iFilasFile > 500000){
				CerrarArchivos();
				MoverArchivos(0);
				printf("Clientes Procesados hasta el momento: %ld\n", cantProcesada);
				if(!AbreArchivos(iPlan, iIndexFile)){
					exit(1);	
				}
				iIndexFile++;
				iFilasFile=0;
				iCantidadArchivos++;
			}
			
		  }else{
			  printf("Clientes %ld sin lectura historica para informar \n", lNroCliente);
		  }
	   }
				
	   $CLOSE curClientes;      
		CerrarArchivos();

		MoverArchivos(0);
		iIndexFile=1;
	}
	
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
	printf("Clientes Procesados : %ld \n", cantProcesada);
    printf("Cantidad de Archivos Generados por tipo: %ld \n", iCantidadArchivos);
    printf("Cantidad de Lecturas Actuales Totales: %ld \n", iCantLecturasActuales);
    printf("Cantidad de Lecturas Pendientes Totales: %ld \n", iCantLecturasPendientes);    
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
   char  sFecha4Y[11];
   
   memset(sFecha4Y, '\0', sizeof(sFecha4Y));
   memset(sFechaDesde, '\0', sizeof(sFechaDesde));
   memset(sFechaHasta, '\0', sizeof(sFechaHasta));

   memset(gsDesdeFmt, '\0', sizeof(gsDesdeFmt));
   memset(gsHastaFmt, '\0', sizeof(gsHastaFmt));
   
	if(argc < 3 || argc > 5 ){
		MensajeParametros();
		return 0;
	}
   giTipoCorrida=atoi(argv[2]);
	
   strcpy(sFecha4Y, argv[3]);
   rdefmtdate(&lFecha4Y, "dd/mm/yyyy", sFecha4Y); 
   
   
   if(argc==5){
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
	printf("	<Fecha Desde (Obligatoria)> dd/mm/aaaa.\n");
	printf("	<Fecha Hasta (Opcional)> dd/mm/aaaa.\n");
      
}

short AbreArchivosActual(iPlan, iIndex)
int	  iPlan;
int   iIndex;
{
   char  sTitulos[10000];
   $char sFecha[9];
   int   iRcv;
   
	memset(sTitulos, '\0', sizeof(sTitulos));
/*--------Misura Pendiente de facturar-------*/
	memset(sArchMisuraPendUnx,'\0',sizeof(sArchMisuraPendUnx));
	memset(sArchMisuraPendAux,'\0',sizeof(sArchMisuraPendAux));
	memset(sArchMisuraPendDos,'\0',sizeof(sArchMisuraPendDos));
	memset(sSoloArchivoPendMisura,'\0',sizeof(sSoloArchivoPendMisura));
/*--------Adjunto Misura Pendiente de facturar-------*/
	memset(sArchMisuraAdjPendUnx,'\0',sizeof(sArchMisuraAdjPendUnx));
	memset(sArchMisuraAdjPendAux,'\0',sizeof(sArchMisuraAdjPendAux));
	memset(sArchMisuraAdjPendDos,'\0',sizeof(sArchMisuraAdjPendDos));
	memset(sSoloArchivoMisuraAdjPend,'\0',sizeof(sSoloArchivoMisuraAdjPend));
/*-------Misura--------*/
	memset(sArchMisuraUnx,'\0',sizeof(sArchMisuraUnx));
	memset(sArchMisuraAux,'\0',sizeof(sArchMisuraAux));
	memset(sArchMisuraDos,'\0',sizeof(sArchMisuraDos));
	memset(sSoloArchivoMisura,'\0',sizeof(sSoloArchivoMisura));
/*--------Adjunto Misura-------*/
	memset(sArchMisuraAdjUnx,'\0',sizeof(sArchMisuraAdjUnx));
	memset(sArchMisuraAdjAux,'\0',sizeof(sArchMisuraAdjAux));
	memset(sArchMisuraAdjDos,'\0',sizeof(sArchMisuraAdjDos));
	memset(sSoloArchivoMisuraAdj,'\0',sizeof(sSoloArchivoMisuraAdj));

	memset(sFecha,'\0',sizeof(sFecha));
	memset(sPathSalida,'\0',sizeof(sPathSalida));

	FechaGeneracionFormateada(sFecha);

	RutaArchivos( sPathSalida, "SMIGEN" );
	alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SMICPY" );
	alltrim(sPathCopia,' ');
	strcat(sPathCopia, "Misura/");

/*--------Misura Pendiente de facturar-------*/
	sprintf( sArchMisuraPendUnx  , "%sLEITURA_PENDIENTE_T1_.unx", sPathSalida );
	sprintf( sArchMisuraPendAux  , "%sLEITURA_PENDIENTE_T1.aux", sPathSalida );
	sprintf( sArchMisuraPendDos  , "%sLEITURA_PENDIENTE_T1_%s_%d_%d.txt", sPathSalida, sFecha, iPlan, iIndex);

/*--------Adjunto Misura Pendiente de facturar-------*/
	sprintf( sArchMisuraAdjPendUnx  , "%sADJUNTO_LEITURA_PENDIENTE_T1.unx", sPathSalida );
	sprintf( sArchMisuraAdjPendAux  , "%sADJUNTO_LEITURA_PENDIENTE_T1.aux", sPathSalida );
	sprintf( sArchMisuraAdjPendDos  , "%sADJUNTO_LEITURA_PENDIENTE_T1_%s_%d_%d.txt", sPathSalida, sFecha, iPlan, iIndex);

/*-------Misura--------*/
	sprintf( sArchMisuraUnx  , "%sLEITURA_ACT_T1_.unx", sPathSalida );
	sprintf( sArchMisuraAux  , "%sLEITURA_ACT_T1.aux", sPathSalida );
	sprintf( sArchMisuraDos  , "%sLEITURA_ACT_T1_%s_%d_%d.txt", sPathSalida, sFecha, iPlan, iIndex);
/*--------Adjunto Misura-------*/
	sprintf( sArchMisuraAdjUnx  , "%sADJUNTO_LEITURA_ACT_T1.unx", sPathSalida );
	sprintf( sArchMisuraAdjAux  , "%sADJUNTO_LEITURA_ACT_T1.aux", sPathSalida );
	sprintf( sArchMisuraAdjDos  , "%sADJUNTO_LEITURA_ACT_T1_%s_%d_%d.txt", sPathSalida, sFecha, iPlan, iIndex);


/*--------Misura Pendiente de facturar-------*/
	pFileMisuraPend=fopen( sArchMisuraPendUnx, "w" );
	if( !pFileMisuraPend ){
		printf("ERROR al abrir archivo %s.\n", sArchMisuraPendUnx );
		return 0;
	}

/*--------Adjunto Misura Pendiente de facturar-------*/
	pFileMisuraAdjPend=fopen( sArchMisuraAdjPendUnx, "w" );
	if( !pFileMisuraAdjPend ){
		printf("ERROR al abrir archivo %s.\n", sArchMisuraAdjPendUnx );
		return 0;
	}

/*-------Misura--------*/
	pFileMisura=fopen( sArchMisuraUnx, "w" );
	if( !pFileMisura ){
		printf("ERROR al abrir archivo %s.\n", sArchMisuraUnx );
		return 0;
	}
/*--------Adjunto Misura-------*/
	pFileMisuraAdj=fopen( sArchMisuraAdjUnx, "w" );
	if( !pFileMisuraAdj ){
		printf("ERROR al abrir archivo %s.\n", sArchMisuraAdjUnx );
		return 0;
	}

	return 1;	
}


short AbreArchivos(iPlan, iIndex)
int	  iPlan;
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
   
	RutaArchivos( sPathSalida, "SMIGEN" );
	alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SMICPY" );
   alltrim(sPathCopia,' ');
   strcat(sPathCopia, "Misura/");

	sprintf( sArchMisuraUnx  , "%sLEITURA_T1.unx", sPathSalida );
   sprintf( sArchMisuraAux  , "%sLEITURA_T1.aux", sPathSalida );
   sprintf( sArchMisuraDos  , "%sLEITURA_T1_%s_%d_%d.txt", sPathSalida, sFecha, iPlan, iIndex);

	sprintf( sArchMisuraAdjUnx  , "%sADJUNTO_LEITURA_T1.unx", sPathSalida );
   sprintf( sArchMisuraAdjAux  , "%sADJUNTO_LEITURA_T1.aux", sPathSalida );
   sprintf( sArchMisuraAdjDos  , "%sADJUNTO_LEITURA_T1_%s_%d_%d.txt", sPathSalida, sFecha, iPlan, iIndex);


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

void MoverArchivos(iFlag)
int	iFlag;
{
char	sCommand[10000];
int	iRcv, i;
	
	if(iFlag==1){
		/* ------ Misura Pendiente ------- */
		sprintf(sCommand, "iconv -f WINDOWS-1252 -t UTF-8 %s > %s ", sArchMisuraPendUnx, sArchMisuraPendDos);
		iRcv=system(sCommand);

		sprintf(sCommand, "chmod 777 %s", sArchMisuraPendDos);
		iRcv=system(sCommand);


		sprintf(sCommand, "mv %s %s", sArchMisuraPendDos, sPathCopia);
		iRcv=system(sCommand);

		if(iRcv >= 0){        
			sprintf(sCommand, "rm %s", sArchMisuraPendUnx);
			iRcv=system(sCommand);
		}
			
		/* ------ Adjunto Misura Pendiente ------- */	
		sprintf(sCommand, "iconv -f WINDOWS-1252 -t UTF-8 %s > %s ", sArchMisuraAdjPendUnx, sArchMisuraAdjPendDos);
		iRcv=system(sCommand);

		sprintf(sCommand, "chmod 777 %s", sArchMisuraAdjPendDos);
		iRcv=system(sCommand);

		sprintf(sCommand, "mv %s %s", sArchMisuraAdjPendDos, sPathCopia);
		iRcv=system(sCommand);

		if(iRcv >= 0){        
		  sprintf(sCommand, "rm %s", sArchMisuraAdjPendUnx);
		  iRcv=system(sCommand);
		}  
	}
	
	/* ------- Misura ------ */
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
   
   /* -------Adjunto Misura------ */
   
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
	strcpy(sql, "SELECT c.numero_cliente, NVL(s.fecha_pivote, TODAY), NVL(s.fecha_move_in, TODAY), c.corr_facturacion, c.estado_cliente ");
	strcat(sql, "FROM cliente c, OUTER sap_regi_cliente s ");
if(giTipoCorrida==1){
   strcat(sql, ", sm_universo m ");
}   
	strcat(sql, "WHERE c.sector = ? ");
	strcat(sql, "AND c.estado_cliente = 0 ");
    strcat(sql, "AND c.tipo_sum NOT IN (5, 6) ");
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cm.fecha_activacion < TODAY ");
	strcat(sql, "AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");	
   strcat(sql, "AND s.numero_cliente = c.numero_cliente ");
if(giTipoCorrida==1){
   strcat(sql, "AND m.numero_cliente = c.numero_cliente ");
}   

	strcat(sql, "UNION ");

	strcat(sql, "SELECT c2.numero_cliente, NVL(s2.fecha_pivote, TODAY), NVL(s2.fecha_move_in, TODAY), c2.corr_facturacion, c2.estado_cliente ");
	strcat(sql, "FROM cliente c2, bal_cliente b, OUTER sap_regi_cliente s2 ");
if(giTipoCorrida==1){
   strcat(sql, ", sm_universo m2 ");
}   
	
	strcat(sql, "WHERE c2.sector = ? ");
	strcat(sql, "AND c2.estado_cliente != 0 ");
    strcat(sql, "AND c2.tipo_sum NOT IN (5, 6) ");
    strcat(sql, "AND b.numero_cliente = c2.numero_cliente ");
    strcat(sql, "AND b.fecha_baja >= ? ");
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm2 ");
	strcat(sql, "WHERE cm2.numero_cliente = c2.numero_cliente ");
	strcat(sql, "AND cm2.fecha_activacion < TODAY ");
	strcat(sql, "AND (cm2.fecha_desactiva IS NULL OR cm2.fecha_desactiva > TODAY)) ");	
   strcat(sql, "AND s2.numero_cliente = c2.numero_cliente ");
if(giTipoCorrida==1){
   strcat(sql, "AND m2.numero_cliente = c2.numero_cliente ");
}   

	$PREPARE selClientes FROM $sql;
	
	$DECLARE curClientes CURSOR WITH HOLD FOR selClientes;

	/******** LECTURAS ACTUALES  ****************/
   $PREPARE selLecturasAct FROM "SELECT FIRST 1 h.numero_cliente, 
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
      FROM hislec h, OUTER sm_transforma t1, 
      OUTER sm_transforma t2, OUTER sm_transforma t3, OUTER sm_transforma t4, 
      OUTER sm_transforma t5, OUTER hislec_reac h2
      WHERE h.numero_cliente = ?
      and h.corr_facturacion = ?
      AND h.tipo_lectura NOT IN (5, 6)
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
      AND h2.fecha_lectura = h.fecha_lectura ";
/*      
      ORDER BY h.fecha_lectura, h.tipo_lectura ASC ";   
	
	$DECLARE curLecturasAct CURSOR WITH HOLD FOR selLecturasAct;
*/		

	/******** Lectura NO Facturada *********/
	$PREPARE selFPLectu FROM "SELECT FIRST 1 f1.numero_cliente,
		f1.corr_facturacion,
		CASE 
		   WHEN f1.fecha_lectura_ver IS NULL THEN f1.fecha_lectura
		   ELSE f1.fecha_lectura_ver
		END fecha_lectura_t2,
		f1.tipo_lectura,
		CASE
		   WHEN f1.tipo_lectura = 1 THEN f1.lectura_prop
		   WHEN f1.tipo_lectura = 4 THEN f1.lectura_a_fact
		   WHEN f1.ind_verificacion='S' AND f1.tipo_lectura in (2,3) AND f1.fecha_lectura_ver IS NOT NULL THEN f1.lectura_verif
		   WHEN f1.ind_verificacion='S' AND f1.tipo_lectura = 2 AND f1.fecha_lectura_ver IS NULL THEN f1.lectura_actual
		   WHEN (f1.ind_verificacion !='S' or f1.ind_verificacion IS NULL) AND f1.tipo_lectura = 2 THEN f1.lectura_actual  
		   ELSE -1
		END lectura_activa,
		f1.numero_medidor,
		f1.marca_medidor,
		f1.clave_lectura_act,
		t1.cod_smile src_deta, 
		t2.cod_smile src_code, 
		t3.cod_smile tip_lectu,
		t4.cod_smile tip_anom,
		t5.cod_smile source_type, 
		CASE
		   WHEN f1.tipo_lectura_reac = 1 THEN f1.lectura_prop_reac
		   WHEN f1.tipo_lectura_reac = 4 THEN f1.lectu_a_fact_reac
		   WHEN f1.ind_verificacion='S' AND f1.tipo_lectura_reac in (2,3) AND f1.fecha_lectura_ver IS NOT NULL THEN f1.lectura_verif_reac
		   WHEN f1.ind_verificacion='S' AND f1.tipo_lectura_reac = 2 AND f1.fecha_lectura_ver IS NULL THEN f1.lectu_actual_reac
		   WHEN (f1.ind_verificacion !='S' or f1.ind_verificacion IS NULL) AND f1.tipo_lectura_reac = 2 THEN f1.lectu_actual_reac 
		   ELSE -1
		END lectura_reactiva
		FROM fp_lectu f1, sm_transforma t1, 
			  sm_transforma t2, sm_transforma t3, OUTER sm_transforma t4, 
			  sm_transforma t5
		WHERE f1.numero_cliente = ?
		AND (f1.corr_facturacion = ? OR f1.corr_fact_ant = ? )
		AND t1.clave = 'SRCDETA'
		AND t1.cod_mac_numerico = f1.tipo_lectura
		AND t2.clave = 'SRCCODE'
		AND t2.cod_mac_numerico = f1.tipo_lectura
		AND t3.clave = 'TIPLECTU'
		AND t3.cod_mac_numerico = f1.tipo_lectura
		AND t4.clave = 'ANOMLECTU'
		AND t4.cod_mac_alfa = f1.clave_lectura_act
		AND t5.clave = 'SRCTYPE'
		AND t5.cod_mac_numerico = f1.tipo_lectura ";
	
	
	/******** Ultima Lectura Real  ****************/
   $PREPARE selUltiLectuReal FROM "SELECT h.numero_cliente, 
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
      and h.corr_facturacion = ?
      AND h.tipo_lectura NOT IN (5, 6, 8)
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
      AND h2.tipo_lectura = h.tipo_lectura ";
	
   /******** Cursor LECTURAS HISTO  ****************/
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
      and h.corr_facturacion <= ?
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
      AND h2.tipo_lectura = h.tipo_lectura
      AND h2.fecha_lectura = h.fecha_lectura
      UNION
	  SELECT h.numero_cliente, 
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
      and h.corr_facturacion >= ?
      AND h.tipo_lectura IN (5, 6)
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
   
	/********* Lectura no Facturada **********/
/*	
SELECT FIRST 1 f1.sucursal,
f1.sector,
f1.tarifa,
CASE 
   WHEN f1.fecha_lectura_ver IS NULL THEN f1.fecha_lectura
   ELSE f1.fecha_lectura_ver
END fecha_lectura_t2,
f1.cons_activa_p1 + f1.cons_activa_p2 consumo_bimestral,
CASE 
   WHEN f1.fecha_lectura_ver IS NOT NULL THEN f1.lectura_verif
   ELSE f1.lectura_actual - f1.lectura_ant
END,
f1.cons_activa_p2,
f1.lectura_ant,
CASE
   WHEN f1.tipo_lectura = 1 THEN f1.lectura_prop
   WHEN f1.tipo_lectura = 4 THEN f1.lectura_a_fact
   WHEN f1.ind_verificacion='S' AND f1.tipo_lectura in (2,3) AND f1.fecha_lectura_ver IS NOT NULL THEN f1.lectura_verif
   WHEN f1.ind_verificacion='S' AND f1.tipo_lectura = 2 AND f1.fecha_lectura_ver IS NULL THEN f1.lectura_actual
   WHEN (f1.ind_verificacion !='S' or f1.ind_verificacion IS NULL) AND f1.tipo_lectura = 2 THEN f1.lectura_actual  
   ELSE -1
END lectura_activa,
CASE
   WHEN f1.tipo_lectura_reac = 1 THEN f1.lectura_prop_reac
   WHEN f1.tipo_lectura_reac = 4 THEN f1.lectu_a_fact_reac
   WHEN f1.ind_verificacion='S' AND f1.tipo_lectura_reac in (2,3) AND f1.fecha_lectura_ver IS NOT NULL THEN f1.lectura_verif_reac
   WHEN f1.ind_verificacion='S' AND f1.tipo_lectura_reac = 2 AND f1.fecha_lectura_ver IS NULL THEN f1.lectu_actual_reac
   WHEN (f1.ind_verificacion !='S' or f1.ind_verificacion IS NULL) AND f1.tipo_lectura_reac = 2 THEN f1.lectu_actual_reac 
   ELSE -1
END lectura_reactiva,
f1.corr_facturacion,
f1.tipo_lectura,
f1.numero_medidor,
f1.marca_medidor,
f1.enteros,
lpad('9',f1.enteros, '9')
FROM fp_lectu f1
WHERE f1.numero_cliente = 4222465
AND f1.corr_facturacion = 95 
*/   
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

short LeoCliente(lNroCliente, lFechaPivote, lFechaMoveIn, iCorrFacturacion, iEstadoCliente)
$long *lNroCliente;
$long *lFechaPivote;
$long *lFechaMoveIn;
$int  *iCorrFacturacion;
$int  *iEstadoCliente;
{
   $long nroCliente;
   $long lFecha;
   $long lFechaMV;
   $int  iCorrFactu;
   $int	 iStsCliente;
   
   $FETCH curClientes INTO :nroCliente, :lFecha, :lFechaMV, :iCorrFactu, :iStsCliente;
   
    if ( SQLCODE != 0 ){
        return 0;
    }
   
   *lNroCliente = nroCliente;
   *lFechaPivote = lFecha;
   *lFechaMoveIn = lFechaMV;
   *iCorrFacturacion = iCorrFactu;
   *iEstadoCliente = iStsCliente;

   return 1;
}

short LeoLecturasAct(lNroCliente, iCorrFactu, regLec, lFechaMoveIn)
$long 	lNroCliente;
$int	iCorrFactu;
$ClsLectura *regLec;
long	lFechaMoveIn;
{
   $double dLecturaActiRectif;
   $double dConsumoActiRectif;
   $double dLecturaReacRectif;
   $double dConsumoReacRectif;
   $char   sRefacturado[2];
   char		sAuxiliar[21];
   int		iVueltas=0;
   
   memset(sRefacturado, '\0', sizeof(sRefacturado));
   memset(sAuxiliar, '\0', sizeof(sAuxiliar));

	InicializaLectura(regLec);
   
	$EXECUTE selLecturasAct INTO 
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
      :regLec->lectura_facturac_reac
      USING :lNroCliente, :iCorrFactu;  
	

    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			/*printf("Cliente %ld sin lectura de ultimo correlativo (lecturas actuales)\n", lNroCliente);*/
			return 0;
		}else{
			printf("Error al leer Lecturas (lecturas actuales) !!!\nProceso Abortado.\n");
			return 0;	
		}
    }			
/*
	if(regLec->tipo_lectura == 8 ){
		printf("Cliente %ld sin lectura REAL en el ultimo correlativo (lecturas actuales)\n", lNroCliente);
		return 0;		
	}

	while ((regLec->tipo_lectura == 8 || regLec->tipo_lectura == 5 || regLec->tipo_lectura == 6) && iVueltas < 3){
		//lNroCliente=regLec->numero_cliente;
		iCorrFactu=regLec->corr_facturacion - 1;
		
		InicializaLectura(regLec);
		
		$EXECUTE selUltiLectuReal INTO
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
		  :regLec->lectura_facturac_reac	
		USING :lNroCliente, :iCorrFactu;

		if ( SQLCODE != 0 ){
			if(SQLCODE == 100){
				printf("Cliente %ld sin lectura actual Fase 1\n", lNroCliente);
				return 0;
			}else{
				printf("Error al leer Lecturas para cliente %ld!!!\nProceso Abortado.\n", lNroCliente);
				return 0;	
			}
		}
				
		iVueltas++;
	}

	if ((regLec->tipo_lectura == 8 || regLec->tipo_lectura == 5 || regLec->tipo_lectura == 6) && iVueltas >=3){
		printf("Cliente %ld sin lectura actual Fase 2\n", lNroCliente);
		return 0;	
	}
*/	
    alltrim(regLec->clave_lectura, ' ');
    alltrim(regLec->src_deta, ' ');
    alltrim(regLec->src_code, ' ');
    alltrim(regLec->tip_lectu, ' ');
    alltrim(regLec->src_type, ' ');
    alltrim(regLec->tip_anom, ' ');
    
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

short LeoLecturaPend(lNroCliente, iCorrFactu, regLec)
$long 	lNroCliente;
$int	iCorrFactu;
$ClsLectura *regLec;
{
   char		sAuxiliar[21];
   memset(sAuxiliar, '\0', sizeof(sAuxiliar));
	
	InicializaLectura(regLec);
   
    iCorrFactu = iCorrFactu-1;
    
	$EXECUTE selFPLectu INTO 
      :regLec->numero_cliente,
      :regLec->corr_facturacion,
      :regLec->fecha_lectura,       
      :regLec->tipo_lectura,
      :regLec->lectura_facturac,
      :regLec->numero_medidor,
      :regLec->marca_medidor,
      :regLec->clave_lectura,
      :regLec->src_deta,
      :regLec->src_code,
      :regLec->tip_lectu,
      :regLec->tip_anom,
      :regLec->src_type,
      :regLec->lectura_facturac_reac
      USING :lNroCliente, :iCorrFactu, :iCorrFactu;  

    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			printf("Cliente %ld sin lectura Pendiente\n", lNroCliente);
			return 0;
		}else{
			printf("Error al leer Lecturas Pendientes Cliente %ld.\n",lNroCliente);
			return 0;	
		}
    }
    
    alltrim(regLec->clave_lectura, ' ');
    alltrim(regLec->src_deta, ' ');
    alltrim(regLec->src_code, ' ');
    alltrim(regLec->tip_lectu, ' ');
    alltrim(regLec->src_type, ' ');
    alltrim(regLec->tip_anom, ' ');
    
    /* Marca Factura Migrada y refacturacion pendiente */
	strcpy(regLec->flag_migrado, "S");
	strcpy(regLec->flag_consumo_pendiente, "N");
    /* Columnizo el tipo de lectura */
    strcpy(sAuxiliar, strReplace(regLec->tip_lectu, "_", "|"));
    strcpy(regLec->tip_lectu, sAuxiliar);    
    
	return 1;
}

short LeoLecturas(regLec, lFechaMoveIn)
$ClsLectura *regLec;
long	lFechaMoveIn;
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


void GenerarPlanoMisura(regLec, iFlag)
$ClsLectura		regLec;
int				iFlag;
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
   

	strcat(sLinea, "\n");
	
	if(iFlag==0){
		iRcv=fprintf(pFileMisura, sLinea);
	}else{
		iRcv=fprintf(pFileMisuraPend, sLinea);		
	}
	
   if(iRcv<0){
      printf("Error al grabar Misura. iFalg %d\n",iFlag);
      exit(1);
   }
}

void GenerarPlanoAdjunto(regLec, iFlag)
$ClsLectura		regLec;
int				iFlag;
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
	sprintf(sLinea, "%s%s|", sLinea, regLec.tip_lectu);

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

int getCorrelativoLectu(lNroCliente, iCorrFacturacion)
$long	lNroCliente;
$int	iCorrFacturacion;
{
	int	iVueltas=0;
	$int iTipo;
	
	$EXECUTE selTipoLectu INTO :iTipo USING :lNroCliente, :iCorrFacturacion;
	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			printf("Cliente %ld sin lectura de ultimo correlativo (lecturas actuales)\n", lNroCliente);
			return 0;
		}else{
			printf("Error al leer Lecturas (lecturas actuales) !!!\nProceso Abortado.\n");
			return 0;	
		}
    }
    
    if(iTipo==0)
		iCorrFacturacion--;
	
	iCorrFacturacion--;

	
	return iCorrFacturacion;
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


