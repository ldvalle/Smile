/********************************************************************************
    Proyecto: Migración MAC SMILE
    Aplicacion: sm_cnr_receive
    
	Fecha : 09/2021

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Carga de Novedades de CNR desde SMILE
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <SYNERGIA>
		
**********************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>
#include "directory.h"
#include "retornavar.h"

$include "sm_cnr_receive.h";

/* Variables Globales */
FILE	*pFileEntrada;
FILE	*pFileLog;

char	sArchivoEntrada[100];
char	sSoloArchivoEntrada[100];

char  	sArchivoTrabajo[100];

char	sArchivoLog[100];
char	sSoloArchivoLog[100];

char	FechaGeneracion[9];	

char	MsgControl[100];
$char	fecha[9];

long	cantArchivos;
long    cantExpedientes;

char	sMensMail[1024];	

/* Variables Globales Host */
$char	sPathEntrada[100];
$char	sPathLog[100];
$char	sPathRepo[100];

$long		lFechaHoy;
$dtime_t    gtInicioCorrida;

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
Tdir    *TdirLotes;
char		unxCmd[500];

	if(! AnalizarParametros(argc, argv)){
		exit(0);
	}
	
	hora = time(&hora);
	
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));
	
	strcpy(nombreBase, argv[1]);
	
	$DATABASE :nombreBase;	
	
	$SET LOCK MODE TO WAIT 120;
	$SET ISOLATION TO DIRTY READ;

	CreaPrepare();

	if (!CargarPaths()){
		printf("No se pudo cargar los paths\nSe aborta el programa.");
		exit(1);
	}

	$EXECUTE selFechaActual INTO :lFechaHoy;
	
		
	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
   dtcurrent(&gtInicioCorrida);
   
	cantArchivos=0;
	cantExpedientes=0;
	
/* ************ BUSCA ARCHIVOS *********** */
	TdirLotes = DirectoryOpen(sPathEntrada);
	if (TdirLotes->dir == NULL){
			 printf("\nERROR al abrirDirectorio\n");
			 exit(1);
	}

	while (DirectoryFetch(TdirLotes, "n", sSoloArchivoEntrada)){
		if(ArchivoValido(sSoloArchivoEntrada)){
			memset(sArchivoTrabajo, '\0', sizeof(sArchivoTrabajo));
			memset(unxCmd, '\0', sizeof(unxCmd));


			sprintf(sArchivoTrabajo, "%s%s", sPathEntrada, sSoloArchivoEntrada);
			
			if(! AbreArchivos(sSoloArchivoEntrada, sArchivoTrabajo)){
				exit(1);
			}
			if(ProcesaArchivo()){
				cantArchivos++;
				
				sprintf(unxCmd, "mv -f %s%s %s%s", sPathEntrada, sSoloArchivoEntrada, sPathRepo, sSoloArchivoEntrada);
				if (system(unxCmd) != 0){
					printf("Error al mover archivo [%s] al repositorio.\n", sSoloArchivoEntrada);
					exit(1);
				}

			}else{
				printf("Archivo [%s] NO se pudo procesar\n", sSoloArchivoEntrada);
				sprintf(unxCmd, "rm -f %s", sArchivoTrabajo);
			}	
		}else{
			printf("Archivo [%s] NO valido\n", sSoloArchivoEntrada);
		}
	}

/* ************ TERMINA CON LOS ARCHIVOS *********** */

	$CLOSE DATABASE;

	$DISCONNECT CURRENT;

	/* ********************************************
				FIN AREA DE PROCESO
	********************************************* */

	printf("==============================================\n");
	printf("SM_CNR_RECEIVE.\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Archivos procesados : %ld \n",cantArchivos);
	printf("Expedientes Procesados : %ld \n",cantExpedientes);
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


short CargarPaths(void){
$char	sPathGral[51];

	memset(sPathGral, '\0', sizeof(sPathGral));
	memset(sPathEntrada, '\0', sizeof(sPathEntrada));
	memset(sPathLog, '\0', sizeof(sPathLog));
	memset(sPathRepo, '\0', sizeof(sPathRepo));

	$EXECUTE selRutas INTO :sPathGral;
	
	if(SQLCODE != 0){
		printf("Error al buscar path general.\n");
		return 0;
	}
	
	alltrim(sPathGral, ' ');
	
	sprintf(sPathEntrada, "%sin/",sPathGral);
	sprintf(sPathLog, "%slog/",sPathGral);
	sprintf(sPathRepo, "%srepo/",sPathGral);
	
	alltrim(sPathEntrada, ' ');
	alltrim(sPathLog, ' ');
	alltrim(sPathRepo, ' ');
		
	return 1;
}


short ArchivoValido(sArchivo)
char	*sArchivo;
{
	char	sMascara[30];
	char	*sSubCadena;
	int	iLargo;
	
	memset(sMascara, '\0', sizeof(sMascara));
	
	strcpy(sMascara, "CnrOut_ED01T1");

	alltrim(sArchivo, ' ');
	
	if (strcmp(sArchivo, ".")  == 0 || strcmp(sArchivo, "..") == 0){
		return 0;
	}

	iLargo=strlen(sArchivo);
	if(iLargo < 14){
		return 0;
	}
	sSubCadena = substring(sArchivo, 1, 15);
	/*alltrim(sSubCadena, ' ');*/

	if( strcmp(sSubCadena, sMascara)!= 0){
		return 0;
	}

	return 1;
}


short AbreArchivos(sArchivoTrab, sPathFileTrab)
char sArchivoTrab[100];
char sPathFileTrab[200];
{
	
	memset(sSoloArchivoLog,'\0',sizeof(sSoloArchivoLog));
	memset(sArchivoLog,'\0',sizeof(sArchivoLog));
	sprintf(sSoloArchivoLog, "%s.log", sArchivoTrab);
	sprintf(sArchivoLog, "%s%s", sPathLog, sSoloArchivoLog);
	
	pFileEntrada=fopen(sPathFileTrab, "r");
	if(! pFileEntrada){
		printf("ERROR al abrir archivo trabajo %s.\n", sPathFileTrab );
		return 0;
	}
	
	pFileLog=fopen( sArchivoLog, "w" );
	if( !pFileLog ){
		printf("ERROR al abrir archivo de log %s.\n", sArchivoLog );
		return 0;
	}

	return 1;	
}


void CerrarArchivos(void){
	fclose(pFileEntrada);
	fclose(pFileLog);
}


short ProcesaArchivo(){
char			sLinea[10000];
$ClsLectura	reg;
long   			iLinea;
char			sMsg[1000];
$int			iCorrFactu;

	fgets(sLinea, 1000, pFileEntrada);
	iLinea=0;
	while (!feof(pFileEntrada)){
		if(iLinea > 0){
			sprintf(sMsg, "Procesando Linea %ld\n", iLinea);
			
			RegistraLog(sMsg);
			fflush(pFileLog);
			
			memset(sMsg, '\0', sizeof(sMsg));
			
			cantExpedientes++;
			CargaRegistro( sLinea, &reg);

			strcpy(sMsg, "\tLinea Procesada\n");
			RegistraLog(sMsg);
			fflush(pFileLog);
	
			if(VerificaCNR(&reg)){
				if(EstadoModifica(&reg)){
					$BEGIN WORK;
					if(!ActualizaCNR(reg)){
						$ROLLBACK WORK;
						sprintf(sMsg, "No Actualizo CNR [%s]\n", sLinea);
						RegistraLog(sMsg);					
					}
					$COMMIT WORK;
				}
			}else{
				sprintf(sMsg, "No Verifica CNR [%s]\n", sLinea);
				RegistraLog(sMsg);
			}
			
		}
		fgets(sLinea, 10000, pFileEntrada);
		iLinea++;
	}
	
	return 1;
}

void CargaRegistro( sLinea, reg)
char			sLinea[10000];
$ClsLectura	*reg;
{
	/*char 	sCampo[100];*/
	int	iRcv;
	int	i;
	char sCampo[200];
	char sAux[20];
	
	memset(sCampo, '\0', sizeof(sCampo));
	
	InicializoRegistro(reg);

	strcpy(sLinea, strReplace(sLinea, "\"", "´"));
	strcpy(sLinea, strReplace(sLinea, "\n", " "));
	strcpy(sLinea, strReplace(sLinea, ",", " "));
	strcpy(sLinea, strReplace(sLinea, "á", "a"));
	strcpy(sLinea, strReplace(sLinea, "é", "e"));
	strcpy(sLinea, strReplace(sLinea, "í", "i"));
	strcpy(sLinea, strReplace(sLinea, "ó", "o"));
	strcpy(sLinea, strReplace(sLinea, "ú", "u"));

	/* ID Expediente */
	if (RetornaCampoVar(sCampo, sLinea, '|', 1)){
		memset(sAux, '\0', sizeof(sAux));
		strcpy(sAux, substring(sCampo, 1, 4));
		alltrim(sAux, ' ');
		strcpy(reg->sucursal, sAux);
		
		memset(sAux, '\0', sizeof(sAux));
		strcpy(sAux, substring(sCampo, 5, 9));
		alltrim(sAux, ' ');
		reg->nroExpediente = atol(sAux);
	}


	/* Fecha Estado */
	if (RetornaCampoVar(sCampo, sLinea, '|', 2)){
		alltrim(sCampo, ' ');
		memset(sAux, '\0', sizeof(sAux));
		dd/mm/aaaa HH:MM:SS
		sprintf(sAux, "%c%c%c%c-%c%c-%c%c %c%c:%c%c:%c%c", sCampo[6],sCampo[7],sCampo[8],sCampo[9],
			sCampo[3],sCampo[4],sCampo[0],sCampo[1],
			sCampo[11],sCampo[12],sCampo[14],sCampo[15], sCampo[17],sCampo[18]);
		strcpy(reg->fechaEstado, sAux);
		
		memset(sAux, '\0', sizeof(sAux));
		sprintf(sAux, "%c%c/%c%c/%c%cc%c", sCampo[0],sCampo[1],sCampo[3],sCampo[4],sCampo[6],sCampo[7],sCampo[8,sCampo[9]);
		alltrim(sAux, ' ');
		rdefmtdate(&(reg->lFechaCierre), "dd/mm/yyyy", sAux);
		
	}

	/* Estado */
	if (RetornaCampoVar(sCampo, sLinea, '|', 3)){
		strcpy(reg->estado, sCampo);
	}
	
	/* Periodo Desde */
	if (RetornaCampoVar(sCampo, sLinea, '|', 4)){
		rdefmtdate(&(reg->periodoDesde), "dd/mm/yyyy", sCampo);
	}

	/* Periodo Hasta */
	if (RetornaCampoVar(sCampo, sLinea, '|', 5)){
		rdefmtdate(&(reg->periodoHasta), "dd/mm/yyyy", sCampo);
	}
	
	/* Monto */
	if (RetornaCampoVar(sCampo, sLinea, '|', 6)){
		reg->monto = atof(sCampo);
	}
	
}

void InicializoRegistro(reg)
$ClsCNR	*reg;
{
	memset(reg->sucursal, '\0', sizeof(reg->sucursal));
	rsetnull(CLONGTYPE, (char *) &(reg->nroExpediente));
	memset(reg->fechaEstado, '\0', sizeof(reg->fechaEstado));
	memset(reg->estado, '\0', sizeof(reg->estado));
	rsetnull(CLONGTYPE, (char *) &(reg->periodoDesde));
	rsetnull(CLONGTYPE, (char *) &(reg->periodoHasta));
	rsetnull(CDOUBLETYPE, (char *) &(reg->monto));
	
	rsetnull(CLONGTYPE, (char *) &(reg->nroCliente));
	rsetnull(CINTTYPE, (char *) &(reg->ano_expediente));
	memset(reg->cod_estado, '\0', sizeof(reg->cod_estado));
	rsetnull(CLONGTYPE, (char *) &(reg->nroCliente));
	memset(reg->cod_provincia, '\0', sizeof(reg->cod_provincia));
	memset(reg->cod_partido, '\0', sizeof(reg->cod_partido));
	memset(reg->cod_localidad, '\0', sizeof(reg->cod_localidad));
	memset(reg->sucursal_cliente, '\0', sizeof(reg->sucursal_cliente));
	rsetnull(CINTTYPE, (char *) &(reg->sector_cliente));
	rsetnull(CINTTYPE, (char *) &(reg->zona_cliente));	
	memset(reg->cod_calle, '\0', sizeof(reg->cod_calle));
	memset(reg->nro_dir, '\0', sizeof(reg->nro_dir));
	memset(reg->piso_dir, '\0', sizeof(reg->piso_dir));
	memset(reg->depto_dir, '\0', sizeof(reg->depto_dir));
	
	rsetnull(CLONGTYPE, (char *) &(reg->lFechaCierre));
}

/*
void FormateaArchivos(void){
char	sCommand[1000];
int		iRcv, i;
char	sPathCp[100];

	memset(sCommand, '\0', sizeof(sCommand));
	memset(sPathCp, '\0', sizeof(sPathCp));

    if(giEstadoCliente==0){

       sprintf(sPathCp, "%sActivos/", sPathCopia);
	}else{

       sprintf(sPathCp, "%sInactivos/", sPathCopia);
	}

	sprintf(sCommand, "chmod 755 %s", sArchDepgarUnx);
	iRcv=system(sCommand);
	
	sprintf(sCommand, "cp %s %s", sArchDepgarUnx, sPathCp);
	iRcv=system(sCommand);
   
   if(iRcv==0){
      sprintf(sCommand, "rm -f %s", sArchDepgarUnx);
      iRcv=system(sCommand);
   }
   
}
*/

void CreaPrepare(void){
$char sql[10000];
$char sAux[1000];

	memset(sql, '\0', sizeof(sql));
	memset(sAux, '\0', sizeof(sAux));
	
	/******** Fecha Actual Formateada ****************/
	strcpy(sql, "SELECT TO_CHAR(TODAY, '%Y%m%d') FROM dual ");
	
	$PREPARE selFechaActualFmt FROM $sql;

	/******** Fecha Actual  ****************/
	strcpy(sql, "SELECT TODAY FROM dual ");
	
	$PREPARE selFechaActual FROM $sql;	
	
	/***************** Rutas Archivos ****************/
	$PREPARE selRutas FROM "SELECT valor_alf FROM tabla
		WHERE nomtabla = 'PATH'
		AND sucursal = '0000'
		AND codigo = 'SMIMAC'
		AND fecha_activacion <= TODAY
		AND (fecha_desactivac IS NULL OR fecha_desactivac > TODAY)";

	/* Recupera Expediente */
	$PREPARE selCNR FROM "SELECT ano_expediente, 
		cod_estado,
		numero_cliente,
		cod_provincia,
		cod_partido,
		cod_localidad,
		sucursal_cliente,
		sector_cliente,
		zona_cliente,
		cod_calle,
		nro_dir, 
		piso_dir,
		depto_dir
		FROM cnr_new
		WHERE sucursal = ?
		AND nro_expediente = ? ";

	/* Cant Clientes x direccion */
	$PREPARE selCantCli FROM "SELECT COUNT(*)
		FROM cliente 
		WHERE provincia = ?
		AND partido = ?
		AND comuna = ?
		AND sucursal = ?
		AND sector = ?
		AND zona = ?
		AND cod_calle = ?
		AND nro_dir = ?
		AND piso_dir = ?
		AND depto_dir = ? ";

	/* Sel Cliente x direccion */
	$PREPARE selCliente FROM "SELECT numero_cliente 
		FROM cliente 
		WHERE provincia = ?
		AND partido = ?
		AND comuna = ?
		AND sucursal = ?
		AND sector = ?
		AND zona = ?
		AND cod_calle = ?
		AND nro_dir = ?
		AND piso_dir = ?
		AND depto_dir = ? ";	

	/* Update CNR con Cierre */
	$PREPARE updCnrCerrado FROM "UPDATE cnr_new SET
		cod_estado = ?,
		fecha_finalizacion = ?,
		fecha_estado = ?, 
		fecha_desde_periodo = ?, 
		fecha_hasta_periodo = ?,
		monto_facturado = ?
		WHERE sucursal = ?
		AND nro_expediente = ? ";

	/* Update CNR sin Cierre */
	$PREPARE updCnrAbierto FROM "UPDATE cnr_new SET
		cod_estado = ?,
		fecha_estado = ?, 
		fecha_desde_periodo = ?, 
		fecha_hasta_periodo = ?,
		monto_facturado = ?
		WHERE sucursal = ?
		AND nro_expediente = ? ";

	/* Actualiza Cliente */
	$PREPARE updCliente FROM "UPDATE cliente SET
		tiene_cnr = ?
		WHERE numero_cliente = ? ";
	
}


void RegistraLog(sLinea)
char	*sLinea;
{
	
	fprintf(pFileLog, sLinea);
	
}


short VerificaCNR(reg)
$ClsCNR *reg;
{
char		sMsg[1000];
$int		iCantClientes=0;
$long 		lNroCliente;

	memset(sMsg, '\0', sizeof(sMsg));
	
	$EXECUTE selCNR INTO :reg->ano_expediente,
		:reg->cod_estado,
		:reg->numero_cliente,
		:reg->cod_provincia,
		:reg->cod_partido,
		:reg->cod_localidad,
		:reg->sucursal_cliente,
		:reg->sector_cliente,
		:reg->zona_cliente,
		:reg->cod_calle,
		:reg->nro_dir,
		:reg->piso_dir,
		:reg->depto_dir	
		USING :reg->sucursal,
			  :reg->nroExpediente;
			  
	if(SQLCODE != 0){
		if(SQLCODE == 100){
			sprintf(sMsg, "No se encontro Expediente CNR Sucursal %s Nro.Expediente %ld\n", reg->sucursal, reg->nroExpediente);
			return 0;
		}
	}
	
	alltrim(reg->cod_provincia, ' ');
	alltrim(reg->cod_partido, ' ');
	alltrim(reg->cod_localidad, ' ');
	alltrim(reg->sucursal_cliente, ' ');
	alltrim(reg->cod_calle, ' ');
	alltrim(reg->nro_dir, ' ');
	alltrim(reg->piso_dir, ' ');
	alltrim(reg->depto_dir, ' ');
	
	if(reg->numero_cliente == 0){
		/* Intento Buscar cliente x la direccion */

		$EXECURE selCantCli INTO :iCantClientes USING
			:reg->cod_provincia,
			:reg->cod_partido,
			:reg->cod_localidad,
			:reg->sucursal_cliente,
			:reg->sector_cliente,
			:reg->zona_cliente,
			:reg->cod_calle,
			:reg->nro_dir,
			:reg->piso_dir,
			:reg->depto_dir;
		
		if(SQLCODE == 0){
			if(iCantClientes == 1){
				$EXECURE selCliente INTO :reg->numero_cliente USING
					:reg->cod_provincia,
					:reg->cod_partido,
					:reg->cod_localidad,
					:reg->sucursal_cliente,
					:reg->sector_cliente,
					:reg->zona_cliente,
					:reg->cod_calle,
					:reg->nro_dir,
					:reg->piso_dir,
					:reg->depto_dir;
			}
		}
	}
	
	return 1;
}

short ActualizaCNR(reg)
$ClsCNR		reg;
{
	char	sMarca[2];
	
	/* Actualizo CNR */
	if(strcmp(reg.cod_estado, "05")== 0 || strcmp(reg.cod_estado, "99")== 0){
		$EXECUTE updCnrCerrado USING :reg.cod_estado,
			:reg.lFechaCierre,
			:reg.fechaEstado,
			:reg.periodoDesde,
			:reg.periodoHasta,
			:reg.monto,
			:reg.sucursal,
			:nroExpediente;
	}else{
		$EXECUTE updCnrAbierto USING :reg.cod_estado,
			:reg.fechaEstado,
			:reg.periodoDesde,
			:reg.periodoHasta,
			:reg.monto,
			:reg.sucursal,
			:nroExpediente;
	}
	
	if(SQLCODE != 0)
		return 0;
	
	
	/* Actualizo Cliente */
	if((strcmp(reg.cod_estado, "05")== 0  || strcmp(reg.cod_estado, "06")== 0 || strcmp(reg.cod_estado, "99")== 0) && (reg.numero_cliente > 0)){
		memset(sMarca, '\0', sizeof(sMarca));
		if(strcmp(reg.cod_estado, "05")== 0
			strcpy(sMarca, "S");

		if(strcmp(reg.cod_estado, "06")== 0
			strcpy(sMarca, "N");

		if(strcmp(reg.cod_estado, "99")== 0
			strcpy(sMarca, "N");		
			
		$EXECUTE updCliente USING :sMarca, :reg.numero_cliente;
		
	}
	
	return 1;
}


short EstadoModifica(reg)
$ClsCNR *reg;
{

	alltrim(reg->estado, ' ');
	
	if(strcmp(reg->estado, "INS")==0){
		return 0;
	}
	if(strcmp(reg->estado, "LAV")==0){
		return 0;
	}
	if(strcmp(reg->estado, "NDR")==0){
		return 0;
	}
	
	if(strcmp(reg->estado, "PRE")==0){
		strcpy(reg->cod_estado, "04");
	}
	if(strcmp(reg->estado, "CON")==0){
		strcpy(reg->cod_estado, "04");
	}
	if(strcmp(reg->estado, "FAT")==0){
		strcpy(reg->cod_estado, "05");
	}
	if(strcmp(reg->estado, "END")==0){
		strcpy(reg->cod_estado, "06");
	}
	if(strcmp(reg->estado, "ANN")==0){
		strcpy(reg->cod_estado, "99");
	}
	
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


static char *strReplace(sCadena, cFind, cRemp)
char sCadena[1000];
char cFind[2];
char cRemp[2];
{

    char *p = sCadena;
    
    while (*p != '\0') {
        if (*p == cFind[0])
            *p = cRemp[0];
        p++;
    }
    
    strcat(sCadena, "\0");
    
    return sCadena;
	
	
/*	
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
*/

}

char *substring(char *string, int position, int length)
{
   char *pointer;
   int c;
 
   pointer = malloc(length+1);
   
   if (pointer == NULL)
   {
      printf("Unable to allocate memory.\n");
      exit(1);
   }
 
   for (c = 0 ; c < length ; c++)
   {
      *(pointer+c) = *(string+position-1);      
      string++;  
   }
 
   *(pointer+c) = '\0';
 
   return pointer;
}

int instr(cadena, patron)
char  *cadena;
char  *patron;
{
   int valor=0;
   int i;
   int largo;
   
   largo = strlen(cadena);
   
   for(i=0; i<largo; i++){
      if(cadena[i]==patron[0])
         valor++;
   }
   return valor;
}

