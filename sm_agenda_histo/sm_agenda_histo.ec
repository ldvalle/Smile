/*********************************************************************************
		
********************************************************************************/
#include <locale.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sm_agenda_histo.h";

/* Variables Globales */
FILE  *fpUnx;
char	sArchivoUnx[100];
char	sSoloArchivoUnx[100];
char  sArchivoUnx2[100];

char	sPathSalida[100];
char	sPathCopia[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
char	sMensMail[1024];	

/* Variables Globales Host */
$dtime_t    gtInicioCorrida;


$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
$ClsAgenda  regAgenda;

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
	
	$OPEN curAgendaSap;
   while(LeoAgenda(&regAgenda)){
      GenerarPlanos(fpUnx, regAgenda);
   }

   $CLOSE curAgendaSap;

   CerrarArchivos();

	$CLOSE DATABASE;

	$DISCONNECT CURRENT;

	/* ********************************************
				FIN AREA DE PROCESO
	********************************************* */
   
   MueveArchivos();

	printf("==============================================\n");
	printf("SMILE - AGENDA HISTORICO\n");
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
   
	if(argc != 2){
		MensajeParametros();
		return 0;
	}
	
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("	<Base> = synergia.\n");

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

	RutaArchivos( sPathSalida, "SAPISU" );
	alltrim(sPathSalida,' ');

	RutaArchivos( sPathCopia, "SAPCPY" );
	alltrim(sPathCopia,' ');
   strcat(sPathCopia, "SMILE/");
   
	sprintf( sArchivoUnx  , "%sT1_agenda_histo.unx", sPathSalida );
	strcpy( sSoloArchivoUnx, "T1_agenda_histo.unx");
   sprintf( sArchivoUnx2  , "%sT1_agenda_historico.unx", sPathSalida );
   
	fpUnx=fopen( sArchivoUnx, "w" );
	if( !fpUnx ){
		printf("ERROR al abrir archivo %s.\n", fpUnx );
		return 0;
	}
	
   strcpy(sTitulo, "Portion|Client Group|Year Month|Initial date-Billing Window|End date-Billing Window|Billing Date|Operative Center");

   strcat(sTitulo, "\n");
   
	fprintf(fpUnx, sTitulo);
   
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

   sprintf(sCommand, "iconv -f windows-1252 -t UTF-8 %s > %s ", sArchivoUnx, sArchivoUnx2);
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

   /* Cursor Agenda SAP */
   
   $PREPARE selAgendaSap FROM "SELECT DISTINCT a1.sector,   
      TO_CHAR(a1.fin_ventana, '%Y%m'),  
      TO_CHAR(a1.inicio_ventana, '%d/%m/%Y'),  
      TO_CHAR(a1.inicio_ventana, '%d/%m/%Y'), 
      TO_CHAR(a1.fin_ventana, '%d/%m/%Y'), 
      a1.ul[1],
      TO_CHAR(a1.inicio_ventana + 20, '%d/%m/%Y'),
      TO_CHAR(MIN(a2.inicio_ventana +15), '%d/%m/%Y')
      FROM sap_agenda a1, OUTER sap_agenda a2
      WHERE a1.tipo_ciclo = 'F' 
      AND a2.porcion = a1.porcion
      AND a2.ul = a1.ul
      AND a2.fecha_generacion > a1.fecha_generacion
      GROUP BY 1,2,3,4,5,6,7 ";
   
   $DECLARE curAgendaSap CURSOR FOR selAgendaSap;   
   
   /* Busca agenda siguiente */
   $PREPARE selAgendaSiguiente FROM "SELECT MIN(inicio_ventana-1) FROM sap_agenda
      WHERE porcion= ?
      AND ul = ?
      AND fecha_generacion > ?
      AND tipo_ciclo = 'F' ";
   
   
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

short LeoAgenda(reg)
$ClsAgenda *reg;
{
   $long lFechaSiguiente;
   
   InicializaAgenda(reg);

	$FETCH curAgendaSap INTO
      :reg->sector,
      :reg->anoMes,
      :reg->dataTablaLectu,
      :reg->dataLectura,
      :reg->dataFacturacion,
      :reg->centroOp,
      :reg->sFechaCierrePropuesta,
      :reg->sFechaCierre;

  if ( SQLCODE != 0 ){
    if(SQLCODE == 100){
      return 0;
    }else{
      printf("Error al leer Cursor de AGENDAS SAP !!!\nProceso Abortado.\n");
      exit(1);	
    }
  }			

   alltrim(reg->sFechaCierrePropuesta, ' ');
   alltrim(reg->sFechaCierre, ' ');
   
   if(strcmp(reg->sFechaCierre, "")!=0){
      strcpy(reg->dataFacturacion, reg->sFechaCierre);
   }else{
      strcpy(reg->dataFacturacion, reg->sFechaCierrePropuesta);
   }
      
   /*rfmtdate(lFechaSiguiente, "dd/mm/yyyy", reg->dataFacturacion); // long to char */

	return 1;	
}

void InicializaAgenda(reg)
$ClsAgenda *reg;
{
   rsetnull(CINTTYPE, (char *) &(reg->sector));
   memset(reg->anoMes, '\0', sizeof(reg->anoMes));
   memset(reg->dataTablaLectu, '\0', sizeof(reg->dataTablaLectu));
   memset(reg->dataLectura, '\0', sizeof(reg->dataLectura));
   memset(reg->dataFacturacion, '\0', sizeof(reg->dataFacturacion));
   memset(reg->centroOp, '\0', sizeof(reg->centroOp));
   
   memset(reg->sFechaCierrePropuesta, '\0', sizeof(reg->sFechaCierrePropuesta));
   memset(reg->sFechaCierre, '\0', sizeof(reg->sFechaCierre));
}

void GenerarPlanos(fpSalida, reg)
FILE        *fpSalida;
ClsAgenda   reg;
{
	char	sLinea[1000];
   int   iRcv;
    
	memset(sLinea, '\0', sizeof(sLinea));

   /* SECTOR */
   sprintf(sLinea, "%d|", reg.sector);
   
   /* GRUPPO CLIENTI */
   strcat(sLinea, "T1|");
   
   /* MESE */
   sprintf(sLinea, "%s%s|", sLinea, reg.anoMes);
   
   /* DATA TABLA LECTU */
   sprintf(sLinea, "%s%s|", sLinea, reg.dataTablaLectu);
   
   /* DATA LEITURA */
   sprintf(sLinea, "%s%s|", sLinea, reg.dataLectura);
   
   /* DATA FATURAMENTO */
   sprintf(sLinea, "%s%s|", sLinea, reg.dataFacturacion);
   
   /* CENTRO OPERATIVO */
   sprintf(sLinea, "%s%s", sLinea, reg.centroOp);

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


