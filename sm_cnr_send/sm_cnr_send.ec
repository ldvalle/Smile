/*********************************************************************************
		
********************************************************************************/
#include <locale.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sm_cnr_send.h";

/* Variables Globales */
FILE  	*fpUnx;
char	sArchivoUnx[100];
char	sSoloArchivoUnx[100];
char  	sArchivoUnx2[100];

char	sPathSalida[100];
char	sPathCopia[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
char	sMensMail[1024];	

/* Variables Globales Host */
$dtime_t    gtInicioCorrida;
$long		gFechaDesde;
$long		gFechaHasta;


$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
$ClsCNR  regCNR;

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
	$SET ISOLATION TO CURSOR STABILITY;
	
	CreaPrepare();

            
	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */

	/*********************************************
				AREA CURSOR PPAL
	**********************************************/
   
   
	if(!AbreArchivos()){
		exit(1);	
	}
	
	$OPEN curCNR USING :gFechaDesde, :gFechaHasta;
	
	while(LeoCNR(&regCNR)){
	  GenerarPlanos(fpUnx, regCNR);
	}

	$CLOSE curCNR;	

	CerrarArchivos();

	$CLOSE DATABASE;

	$DISCONNECT CURRENT;

	/* ********************************************
				FIN AREA DE PROCESO
	********************************************* */
   
   MueveArchivos();

	printf("==============================================\n");
	printf("SMILE - Envio de CNRs\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
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
	char  sFechaDesde[11];
	char  sFechaHasta[11];
   
	if(argc != 4){
		MensajeParametros();
		return 0;
	}
	
	memset(sFechaDesde, '\0', sizeof(sFechaDesde));
	memset(sFechaHasta, '\0', sizeof(sFechaHasta));

	strcpy(sFechaDesde, argv[2]); 
	strcpy(sFechaHasta, argv[3]);
	
	
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("	<Base> = synergia.\n");
		printf("	<Fecha Inicio Desde> = dd/mm/aaaa.\n");
		printf("	<Fecha Inicio Hasta> = dd/mm/aaaa.\n");

}

short AbreArchivos()
{
   char sTitulo[1000];
   	
   memset(sTitulo,'\0',sizeof(sTitulo));
	memset(sArchivoUnx,'\0',sizeof(sArchivoUnx));
	memset(sSoloArchivoUnx,'\0',sizeof(sSoloArchivoUnx));
   memset(sArchivoUnx2,'\0',sizeof(sArchivoUnx2));
   
   FechaGeneracionFormateada(FechaGeneracion);

	memset(sPathSalida,'\0',sizeof(sPathSalida));
	memset(sPathCopia,'\0',sizeof(sPathCopia));   

	RutaArchivos( sPathSalida, "SMIGEN" );
	alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SMICPY" );
	alltrim(sPathCopia,' ');
   strcat(sPathCopia, "cnr/");
   
	sprintf( sArchivoUnx  , "%sT1_cnr_send.unx", sPathSalida );
	strcpy( sSoloArchivoUnx, "T1_cnr_send.unx");
   
	fpUnx=fopen( sArchivoUnx, "w" );
	if( !fpUnx ){
		printf("ERROR al abrir archivo %s.\n", fpUnx );
		return 0;
	}
/*	
   strcpy(sTitulo, "Portion|Client Group|Year Month|Initial date-Billing Window|End date-Billing Window|Billing Date|Operative Center");

   strcat(sTitulo, "\n");
   
	fprintf(fpUnx, sTitulo);
*/   
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

	memset(sCommand, '\0', sizeof(sCommand));

   /*sprintf(sCommand, "iconv -f windows-1252 -t UTF-8 %s > %s ", sArchivoUnx, sArchivoUnx2);*/
   sprintf(sCommand, "iconv -f ISO8859-1 -t UTF-8 %s > %s ", sArchivoUnx, sArchivoUnx2);
   iRcv=system(sCommand);


	sprintf(sCommand, "chmod 755 %s", sArchivoUnx2);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "mv %s %s", sArchivoUnx2, sPathCopia);
	iRcv=system(sCommand);		
/*
   if(iRcv == 0){
      sprintf(sCommand, "rm %s", sArchivoUnx);
      iRcv=system(sCommand);
   }
*/   
}

void FormateaArchivos(sSucur, indice)
char  sSucur[5];
int   indice;
{
char	sCommand[1000];
int	iRcv, i;


	memset(sCommand, '\0', sizeof(sCommand));

	sprintf(sCommand, "chmod 755 %s", sArchivoUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "mv %s %s", sArchivoUnx, sPathCopia);
	iRcv=system(sCommand);		

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

   /* Cursor CNR */
   
   $PREPARE selCNR FROM "SELECT cn.numero_cliente,
	cn.cod_estado,
	TO_CHAR(cn.fecha_inicio, '%Y-%m-%d 00:00:00'),
	cn.sucursal || LPAD(cn.nro_expediente, 10, '0') id_expe,
	TO_CHAR(i.fecha_inspeccion, '%Y-%m-%d %H:%M:%S'),
	cn.tipo_expediente,
	TRIM(cn.cod_anomalia) || '-' || TRIM(ac.descripcion)
	FROM cnr_new cn, OUTER inspecc:in_inspeccion i, OUTER inspecc:in_anom_comercial ac
	WHERE cn.fecha_inicio BETWEEN ? AND ?
	AND cn.cod_estado IN ('01', '02', '03')
	AND i.nro_solicitud = cn.in_solicitud_ap
	AND ac.codigo = cn.cod_anomalia ";
   
   $DECLARE curCNR CURSOR FOR selCNR;   
      
   
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

short LeoCNR(reg)
$ClsCNR *reg;
{
   $long lFechaSiguiente;
   
   InicializaCNR(reg);

	$FETCH curCNR INTO
		:reg->numero_cliente,
		:reg->cod_estado,
		:reg->fecha_inicio,
		:reg->id_expediente,
		:reg->fecha_inspeccion,
		:reg->tipo_expediente
		:reg->anomalia;

  if ( SQLCODE != 0 ){
    if(SQLCODE == 100){
      return 0;
    }else{
      printf("Error al leer Cursor de CNRS !!!\nProceso Abortado.\n");
      exit(1);	
    }
  }			

	alltrim(reg->anomalia, ' ');
      
   /*rfmtdate(lFechaSiguiente, "dd/mm/yyyy", reg->dataFacturacion); // long to char */

	return 1;	
}

void InicializaCNR(reg)
$ClsCNR *reg;
{
   rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   memset(reg->cod_estado, '\0', sizeof(reg->cod_estado));
   memset(reg->fecha_inicio, '\0', sizeof(reg->fecha_inicio));
   memset(reg->id_expediente, '\0', sizeof(reg->id_expediente));
   memset(reg->fecha_inspeccion, '\0', sizeof(reg->fecha_inspeccion));
   memset(reg->tipo_expediente, '\0', sizeof(reg->tipo_expediente));
   memset(reg->anomalia, '\0', sizeof(reg->anomalia));
}

void GenerarPlanos(fpSalida, reg)
FILE        *fpSalida;
ClsAgenda   reg;
{
	char	sLinea[1000];
	int   iRcv;

	memset(sLinea, '\0', sizeof(sLinea));

	/* ENELTEL */
	sprintf(sLinea, "%ld|", reg.numero_cliente);
	
	/* STATO */
	/*sprintf(sLinea, "%s%s|", sLinea, reg.cod_estado);*/
	strcat(sLinea, "INS|");
	
	/* DT_MOD_STATO */
	sprintf(sLinea, "%s%s|", sLinea, reg.fecha_inicio);
	
	/* DT_INS */
	sprintf(sLinea, "%s%s|", sLinea, reg.fecha_inicio);
	
	/* SYN_ORDER_NUMBER */
	sprintf(sLinea, "%s%s|", sLinea, reg.id_expediente);
	
	/* SYN_SELECTION_TYPE */
	sprintf(sLinea, "%s%s|", sLinea, reg.id_expediente);
	
	/* SYN_EMITING_AREA */
	strcat(sLinea, "|");
	/* SYN_EXECUTION_START */
	strcat(sLinea, "|");
	/* SYN_EXECUTION_END */
	strcat(sLinea, "|");
	/* SYN_SITUATION_CODE */
	strcat(sLinea, "|");
	/* SYN_EXECUTION_TYPE */
	strcat(sLinea, "|");
	/* SYN_ORDER_TYPE */
	strcat(sLinea, "|");
	/* SYN_STATUS_CODE */
	strcat(sLinea, "|");
	
	/* SYN_COMPANY */
	strcat(sLinea, "ED01|");
	
	/* SYN_LAST_ORDER_EXECUTED */
	strcat(sLinea, "|"); /* TODO buscar la fecha de la ultima ot del cliente si la hubiera */
	
	/* SYN_START_ANALYSIS_REFERENCE */
	strcat(sLinea, "|");
	/* SYN_END_ANALYSIS_REFERENCE */
	strcat(sLinea, "|");
	
	/* FECHA_INSPECCION */
	sprintf(sLinea, "%s%s|", sLinea, reg.fecha_inspeccion);
	
	/* FECHA_NORMALIZACION */
	strcat(sLinea, "|");
	
	/* FLAG_DOLO */
	if(regtipo_expediente[0]== 'C'){ 
		strcat(sLinea, "Y|");
	}else{
		strcat(sLinea, "N|");
	}
	
	/* TIPO_IRREGULARIDAD */
	sprintf(sLinea, "%s%s|", sLinea, reg.anomalia)
	
	/* CNR_ANTERIOR_FECHA_INICIO */
	strcat(sLinea, "|");
	/* CNR_ANTERIOR_FECHA_FIN */
	strcat(sLinea, "|");
	/* COEFICIENTE_DE_CORRECCION */
	strcat(sLinea, "|");
	/* VALOR_FISCAL */
	strcat(sLinea, "|");
	/* DIAS_FISCAL */
	strcat(sLinea, "|");
	/* DESCRIPCION_ARTEFACTOS */
	strcat(sLinea, "|");
	/* POTENCIA_ARTEFACTOS */
	strcat(sLinea, "|");
	/* HORAS_USO */
	strcat(sLinea, "|");
	/* FACTOR_CARGA */
	if(regtipo_expediente[0]== 'C'){ 
		strcat(sLinea, "40|");
	}else{
		strcat(sLinea, "|");
	}
	
	/* FACTOR_DEMANDA */
	strcat(sLinea, "|");
	/* FLAG_CARGA_DESVIADA_PARCIAL */
	strcat(sLinea, "|");
	/* CARGA_INSTALADA_TOTAL */
	strcat(sLinea, "|");
	/* FECHA_CONEXION_DIRECTA */
	strcat(sLinea, "|");
	/* TARIFA */
	strcat(sLinea, "|");
	/* TRAMO_ETR */
	strcat(sLinea, "|");
	/* CONTRATISTAS */
	strcat(sLinea, "|");
	/* FLAG_ENVIO_AUTOMATICO */
	strcat(sLinea, "|");
	/* ID_INSPECCION */
	strcat(sLinea, "|");
	/* ID_INSPECCION_ANTERIOR */
	strcat(sLinea, "|");
	/* ANALISIS_DE_LA_INSPECCION */
	strcat(sLinea, "|");
	/* FECHA_ANALISIS_INSPECCION */
	strcat(sLinea, "|");
	/* FECHA_ULTIMA_INSPECCION_OK */
	strcat(sLinea, "|");


   strcat(sLinea, "\n");
   
	iRcv=fprintf(fpSalida, sLinea);
   if(iRcv < 0){
      printf("Error al escribir archivo\n");
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


