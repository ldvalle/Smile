/********************************************************************************
    Proyecto: Migración MAC SMILE
    Aplicacion: sm_carga_lecturas
    
	Fecha : 09/2021

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Carga de Lecturas de Ciclo a MAC
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <INSPECC>
		
**********************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>
#include "directory.h"
#include "retornavar.h"

$include "sm_carga_lecturas.h";

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
long    cantLecturas;

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
	cantLecturas=0;
	
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
	printf("SM_CARGA_LECTUTRAS.\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Archivos procesados : %ld \n",cantArchivos);
	printf("Lecturas Procesadas : %ld \n",cantLecturas);
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
		printf("	<Base> = inspecc.\n");
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
	
	strcpy(sMascara, "LEITURA_T1");

	alltrim(sArchivo, ' ');
	
	if (strcmp(sArchivo, ".")  == 0 || strcmp(sArchivo, "..") == 0){
		return 0;
	}

	iLargo=strlen(sArchivo);
	if(iLargo < 16){
		return 0;
	}
	sSubCadena = substring(sArchivo, 1, 16);
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
		sprintf(sMsg, "Procesando Linea %ld\n", iLinea);
		
		RegistraLog(sMsg);
		fflush(pFileLog);
		
		memset(sMsg, '\0', sizeof(sMsg));
		
		cantLecturas++;
		CargaRegistro( sLinea, &reg);

		strcpy(sMsg, "\tLinea Procesada\n");
		RegistraLog(sMsg);
		fflush(pFileLog);
		
		iCorrFactu=0;
		if(VerificaCliente(&iCorrFactu, reg.nroCliente){
			$BEGIN WORK;
			
			if(!risnull(CLONGTYPE, (char *) &(reg.fechaAjuste))){
				if(!CargaLecturaFacturada(iCorrFactu, reg)){
					$ROLLBACK WORK;
					strcpy(sMsg, "Facturada Erronea [%s]\n", sLinea);
					RegistraLog(sMsg);
				}
			}else{
				if(!CargaLecturaAjustada(reg)){
					$ROLLBACK WORK;
					strcpy(sMsg, "Ajustada Erronea [%s]\n", sLinea);
					RegistraLog(sMsg);
				}
			}
			
			$COMMIT WORK;
		}else{
			strcpy(sMsg, "No Verifica Cliente [%s]\n", sLinea);
			RegistraLog(sMsg);
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

	/* Numero Cliente */
	if (RetornaCampoVar(sCampo, sLinea, '|', 1)){
		memset(sAux, '\0', sizeof(sAux));
		strcpy(sAux, substring(sCampo, 7, 9));
		reg->nroCliente = atol(sAux);
	}

	/* corrFacturacion */
	
	/* Nro.Medidor */
	if (RetornaCampoVar(sCampo, sLinea, '|', 3)){
		reg->nroMedidor = atol(sCampo);
	}
	
	/* marca medidor */
	if (RetornaCampoVar(sCampo, sLinea, '|', 4)){
		reg->marcaMedidor = atol(sCampo);
	}
	
	/* Lectura Facturada Activa*/
	if (RetornaCampoVar(sCampo, sLinea, '|', 15)){
		reg->lecturaFacturacActiva = atof(sCampo);
	}
	
	/* Lectura Facturada ReActiva*/
	if (RetornaCampoVar(sCampo, sLinea, '|', 16)){
		alltrim(sCampo, ' ')
		if(strcmp(sCampo, "")!= 0
			reg->lecturaFacturacReactiva = atof(sCampo);
	}
	
	/* LecturaTerreno Activa */
	if (RetornaCampoVar(sCampo, sLinea, '|', 41)){
		reg->lecturaTerrenoActiva = atof(sCampo);
	}
	
	/* LecturaTerreno ReActiva */
	if (RetornaCampoVar(sCampo, sLinea, '|', 42)){
		alltrim(sCampo, ' ')
		if(strcmp(sCampo, "")!= 0
			reg->lecturaTerrenoReactiva = atof(sCampo);
	}
	
	/* Consumo Activa */
	if (RetornaCampoVar(sCampo, sLinea, '|', 28)){
		reg->consumoActivo = atol(sCampo);
	}
	
	/* Consumo Reactiva */
	if (RetornaCampoVar(sCampo, sLinea, '|', 29)){
		alltrim(sCampo, ' ')
		if(strcmp(sCampo, "")!= 0
			reg->consumoReactivo = atol(sCampo);
	}
	
	/* Fecha Lectura*/
	if (RetornaCampoVar(sCampo, sLinea, '|', 10)){
		rdefmtdate(&(reg->fechaLectura), "dd/mm/yyyy", sCampo)
	}

	/* Clave Lectura */
	if (RetornaCampoVar(sCampo, sLinea, '|', 36)){
		alltrim(sCampo, ' ');
		strcpy(reg->claveLectura, sCampo);
	}
	
	/* Tipo Lectura */
	if (RetornaCampoVar(sCampo, sLinea, '|', 23)){
		alltrim(sCampo, ' ');
		reg->tipoLectura = atoi(sCampo);
	}
	
	/* Constante */
	reg->constante = 1;
	
	/* Correlativo Contador */
	ret->correlContador = 1;
	
	/* Coseno Phi */
	
	/* Fecha Ajuste */
	if (RetornaCampoVar(sCampo, sLinea, '|', 99)){
		alltrim(sCampo, ' ');
		rdefmtdate(&(reg->fechaAjuste), "dd/mm/yyyy", sCampo)
	}



/************/
	if (RetornaCampoVar(sCampo, sLinea, '\t', 2)){
		reg->nro_medidor = atol(sCampo);
	}

	if (RetornaCampoVar(sCampo, sLinea, '\t', 3)){
		strcpy(reg->cod_motivo, sCampo);
		alltrim(reg->cod_motivo, ' ');
	}

	if (RetornaCampoVar(sCampo, sLinea, '\t', 5)){
		iRcv=atoi(sCampo);
		memset(sCampo, '\0', sizeof(sCampo));
		sprintf(sCampo, "%04d", iRcv);
		strcpy(reg->cod_sucursal, sCampo);
		alltrim(reg->cod_sucursal, ' ');
	}

	if (RetornaCampoVar(sCampo, sLinea, '\t', 7)){
		iRcv=atoi(sCampo);
		memset(sCampo, '\0', sizeof(sCampo));
		sprintf(sCampo, "%03d", iRcv);
		strcpy(reg->cod_partido, sCampo);
		alltrim(reg->cod_partido, ' ');
	}


	if (RetornaCampoVar(sCampo, sLinea, '\t', 8)){
		strcpy(reg->nom_partido, sCampo);
		alltrim(reg->nom_partido, ' ');
	}

	if (RetornaCampoVar(sCampo, sLinea, '\t', 9)){
		iRcv=atoi(sCampo);
		memset(sCampo, '\0', sizeof(sCampo));
		sprintf(sCampo, "%03d", iRcv);
		strcpy(reg->cod_localidad, sCampo);
		alltrim(reg->cod_localidad, ' ');
	}

	if (RetornaCampoVar(sCampo, sLinea, '\t', 10)){
		strcpy(reg->nom_localidad, sCampo);
		alltrim(reg->nom_localidad, ' ');
	}

	if (RetornaCampoVar(sCampo, sLinea, '\t', 11)){
		strcpy(sCampo, strReplace(sCampo, "\"", "´"));
		strcpy(sCampo, strReplace(sCampo, ",", " "));
		strcpy(sCampo, strReplace(sCampo, "\n", " "));
		
		strcpy(reg->nom_calle, sCampo);
		alltrim(reg->nom_calle, ' ');
	}

	if (RetornaCampoVar(sCampo, sLinea, '\t', 12)){
		strcpy(reg->altura, sCampo);
		alltrim(reg->altura, ' ');
	}

	if (RetornaCampoVar(sCampo, sLinea, '\t', 13)){
		strcpy(reg->piso, sCampo);
		alltrim(reg->piso, ' ');
	}

	if (RetornaCampoVar(sCampo, sLinea, '\t', 14)){
		strcpy(reg->depto, sCampo);
		alltrim(reg->depto, ' ');
	}

	if (RetornaCampoVar(sCampo, sLinea, '\t', 15)){
		strcpy(sCampo, strReplace(sCampo, "\"", "´"));
		strcpy(sCampo, strReplace(sCampo, ",", " "));
		strcpy(sCampo, strReplace(sCampo, "\n", " "));
		
		strcpy(reg->nom_entre_calle1, sCampo);
		alltrim(reg->nom_entre_calle1, ' ');
	}

	if (RetornaCampoVar(sCampo, sLinea, '\t', 16)){
		strcpy(sCampo, strReplace(sCampo, "\"", "´"));
		strcpy(sCampo, strReplace(sCampo, ",", " "));
		strcpy(sCampo, strReplace(sCampo, "\n", " "));
		
		strcpy(reg->nom_entre_calle2, sCampo);
		alltrim(reg->nom_entre_calle2, ' ');
	}


	if (RetornaCampoVar(sCampo, sLinea, '\t', 17)){
		strcpy(sCampo, strReplace(sCampo, "\"", "´"));
		strcpy(sCampo, strReplace(sCampo, ",", " "));
		strcpy(sCampo, strReplace(sCampo, "\n", " "));
		strcpy(reg->observaciones, sCampo);
		alltrim(reg->observaciones, ' ');
	}


	if (RetornaCampoVar(sCampo, sLinea, '\t', 20)){
		strcpy(reg->denunciante, sCampo);
		alltrim(reg->denunciante, ' ');
	}

	if (RetornaCampoVar(sCampo, sLinea, '\t', 23)){
		strcpy(reg->plan, sCampo);
		alltrim(reg->plan, ' ');
	}

	if (RetornaCampoVar(sCampo, sLinea, '\t', 24)){
		strcpy(reg->radio, sCampo);
		alltrim(reg->radio, ' ');
	}

	if (RetornaCampoVar(sCampo, sLinea, '\t', 25)){
		strcpy(reg->recorrido, sCampo);
		alltrim(reg->recorrido, ' ');
	}

/*
	strcpy(reg->observaciones, strReplace(reg->observaciones, "\"", "´"));

	strcpy(reg->observaciones, strReplace(reg->observaciones, "\n", " "));

	strcpy(reg->observaciones, strReplace(reg->observaciones, "\t", " "));

	strcpy(reg->observaciones, strReplace(reg->observaciones, ",", " "));
*/
	alltrim(reg->observaciones, ' ');


}

void InicializoRegistro(reg)
$ClsLectura	*reg;
{

	rsetnull(CLONGTYPE, (char *) &(reg->nroCliente));
	rsetnull(CINTTYPE, (char *) &(reg->corrFacturacion));
	rsetnull(CLONGTYPE, (char *) &(reg->nroMedidor));
	memset(reg->marcaMedidor, '\0', sizeof(reg->marcaMedidor));
	
	rsetnull(CFLOATTYPE, (char *) &(reg->lecturaFacturacActiva));
	rsetnull(CFLOATTYPE, (char *) &(reg->lecturaTerrenoActiva));
	
	rsetnull(CFLOATTYPE, (char *) &(reg->lecturaFacturacReactiva));
	rsetnull(CFLOATTYPE, (char *) &(reg->lecturaTerrenoReactiva));
	
	rsetnull(CLONGTYPE, (char *) &(reg->consumoActivo));
	rsetnull(CLONGTYPE, (char *) &(reg->consumoReactivo));
	
	rsetnull(CLONGTYPE, (char *) &(reg->fechaLectura));
	memset(reg->claveLectura, '\0', sizeof(reg->claveLectura));
	rsetnull(CINTTYPE, (char *) &(reg->tipoLectura));
	rsetnull(CFLOATTYPE, (char *) &(reg->constante));
	rsetnull(CINTTYPE, (char *) &(reg->correlContador));
	memset(reg->tipoEnergia, '\0', sizeof(reg->tipoEnergia));
	rsetnull(CFLOATTYPE, (char *) &(reg->cosPhi));
	rsetnull(CLONGTYPE, (char *) &(reg->fechaAjuste));
	
}

short ValidoRegistro(reg)
$ClsDenuncia	reg;
{
	char sLineaLog[1000];
	int  iRcv;
		
	memset(sLineaLog, '\0', sizeof(sLineaLog));
	return 1;
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

	

	/** valida cliente **/
	$PREPARE selExisteCliente FROM "SELECT corr_facturacion FROM cliente
		WHERE numero_cliente = ? ";

	/** Inserta Hislec **/
	$PREPARE insHislec FROM "INSERT INTO hislec(
		numero_cliente,
		corr_facturacion,
		numero_medidor,
		marca_medidor,
		lectura_facturac,
		lectura_terreno,
		consumo,
		fecha_lectura,
		clave_lectura,
		tipo_lectura,
		constante
		correl_contador
		)VALUES(?,?,?,?,?,?,?,?,?,?,1,1) ";
		
	/** Inserta Hislec Reac **/
	$PREPARE insHislecReac FROM "INSERT INTO hiselec_reac(
		numero_cliente,
		corr_facturacion,
		numero_medidor,
		marca_medidor,
		lectu_factu_reac,
		lectu_terreno_reac,
		consumo_reac,
		fecha_lectura,
		tipo_lectura,
		coseno_phi
		)VALUES(?,?,?,?,?,?,?,?,?,100) ");

	/** Actualiza Cliente **/
	$PREPARE updCliente FROM "UPDATE cliente SET
		corr_facturacion = ?
		WHERE numero_cliente = ? ";

	/** Actualiza Medid 1 **/
	$PREPARE updMedid1 FROM "UPDATE medid SET
		ultima_lect_activa = ?
		WHERE numero_cliente = ?
		AND numero_medidor = ?
		AND marca_medidor = ?
		AND estado = 'I' ";

	/** Actualiza Medid 2 **/
	$PREPARE updMedid2 FROM "UPDATE medid SET
		ultima_lect_activa = ?,
		ultima_lect_reac = ?
		WHERE numero_cliente = ?
		AND numero_medidor = ?
		AND marca_medidor = ?
		AND estado = 'I' ";


}

short ExisteCliente(nroCliente, reg)
$long			nroCliente;
$ClsSolicitud	*reg;
{
	char	sMsgErr[100];
	$char	sTieneCnr[2];
	
	memset(sMsgErr, '\0', sizeof(sMsgErr));
	memset(sTieneCnr, '\0', sizeof(sTieneCnr));
	
	InicializaSolicitud(reg);
	
	$EXECUTE selCliente INTO
		:reg->numero_cliente,
		:reg->sucursal,
		:reg->plan,
		:reg->radio,
		:reg->correlativo_ruta,
		:sTieneCnr,
		:reg->dir_provincia,
		:reg->dir_nom_provincia,
		:reg->dir_partido,
		:reg->dir_nom_partido,
		:reg->dir_comuna,
		:reg->dir_nom_comuna,
		:reg->dir_cod_calle,
		:reg->dir_nom_calle,
		:reg->dir_numero,
		:reg->dir_piso, 
		:reg->dir_depto,
		:reg->dir_cod_postal,
		:reg->telefono,
		:reg->dir_cod_entre,
		:reg->dir_nom_entre,
		:reg->dir_cod_entre1,
		:reg->dir_nom_entre1,
		:reg->dir_observacion,
		:reg->dir_cod_barrio,
		:reg->dir_nom_barrio,
		:reg->dir_manzana,
		:reg->nombre,
		:reg->tip_doc,
		:reg->nro_doc,
		:reg->antiguedad_saldo,
		:reg->estado_cliente,
		:reg->nro_medidor,
		:reg->marca_medidor,
		:reg->modelo_medidor
	USING :nroCliente;
		
	if(SQLCODE != 0){
		if(SQLCODE == 100){
			sprintf(sMsgErr, "Cliente %ld NO existe.\n", nroCliente);
			RegistraLog(sMsgErr);
			return 0;
		}else{
			sprintf(sMsgErr, "Cliente %ld. Error buscando cliente.\n", nroCliente);
			RegistraLog(sMsgErr);
			return 0;
		}
	}else{
		if(reg->estado_cliente != 0){
			sprintf(sMsgErr, "Cliente %ld. Ya no es un cliente activo.\n", nroCliente);
			RegistraLog(sMsgErr);
			return 0;
		}
	}
	
	alltrim(reg->sucursal, ' ');
	alltrim(reg->dir_provincia, ' ');
	alltrim(reg->dir_nom_provincia, ' ');
	alltrim(reg->dir_partido, ' ');
	alltrim(reg->dir_nom_partido, ' ');
	alltrim(reg->dir_comuna, ' ');
	alltrim(reg->dir_nom_comuna, ' ');
	alltrim(reg->dir_cod_calle, ' ');
	alltrim(reg->dir_nom_calle, ' ');
	alltrim(reg->dir_numero, ' ');
	alltrim(reg->dir_piso, ' ');
	alltrim(reg->dir_depto, ' ');
	alltrim(reg->telefono, ' ');
	alltrim(reg->dir_cod_entre, ' ');
	alltrim(reg->dir_nom_entre, ' ');
	alltrim(reg->dir_cod_entre1, ' ');
	alltrim(reg->dir_nom_entre1, ' ');
	alltrim(reg->dir_observacion, ' ');
	alltrim(reg->dir_cod_barrio, ' ');
	alltrim(reg->dir_nom_barrio, ' ');
	alltrim(reg->dir_manzana, ' ');
	alltrim(reg->nombre, ' ');
	alltrim(reg->tip_doc, ' ');
	alltrim(sTieneCnr, ' ');
	
	if(sTieneCnr[0]=='S'){
		reg->tiene_cnr=1;
	}else{
		reg->tiene_cnr=0;
	}
	
	return 1;
}


void RegistraLog(sLinea)
char	*sLinea;
{
	
	fprintf(pFileLog, sLinea);
	
}




short VerificaCliente(icorrFactu, nroCliente)
$int	*iCorrFactu;
$long 	nroCliente;
{
	$int	iCantidad;
	
	$EXECUTE selExisteCliente INTO :iCantidad USING :nroCliente;
	
	if(SQLCODE!=0){
		return 0;
	}
	
	*icorrFactu = iCantidad;
			
	return 1;
}

short CargaLecturaFacturada(iCorrFactu, reg)
$int	iCorrFactu;
$ClsLectura reg;
{
	char			sMsg[1000];
	
	memset(sMsg, '\0', sizeof(sMsg));
	
	iCorrFactu++;
		
	/* grabar lectura activa */
	if(!GrabaLectuActiva(iCorrFactu, reg)){
		sprintf(sMsg, "Cliente %ld Fallo GrabaLectuActiva\n", reg.nroCliente);
		RegistraLog(sMsg);
		return 0;
	}
	
	
	if(!risnull(CLONGTYPE, (char *) &(reg.consumoReactivo))){
		/* grabar lectura reactiva */
		if(!GrabaLectuReActiva(iCorrFactu, reg)){
			sprintf(sMsg, "Cliente %ld Fallo GrabaLectuReActiva\n", reg.nroCliente);
			RegistraLog(sMsg);
			return 0;
		}
	}
	
	/* Actualizar correlativo facturacion cliente */
	$EXECUTE updCliente USING :iCorrFactu, :reg.nroCliente;
	
	if(SQLCODE != 0){
		sprintf(sMsg, "Cliente %ld Fallo Actualizacion del Cliente\n", reg.nroCliente);
		RegistraLog(sMsg);
		return 0;
	}
	
	return 1;
}

short GrabaLectuActiva(iCorrFactu, reg)
$int		iCorrFactu;
$ClsLectura	reg;
{
	
	$EXECUTE insHislec USING
		:reg.nroCliente,
		:iCorrFactu,
		:reg.nroMedidor,
		:reg.marcaMedidor,
		:reg.lecturaFacturacActiva,
		:reg.lecturaTerrenoActiva,
		:reg.consumoActivo,
		:reg.fechaLectura,
		:reg.claveLectura,
		:reg.tipoLectura;
	
	if(SQLCODE != 0)
		return 0;
		
	return 1;
}


short GrabaLectuReActiva(iCorrFactu, reg)
$int		iCorrFactu;
$ClsLectura	reg;
{
	
	$EXECUTE insHislecReac USING
		:reg.nroCliente,
		:iCorrFactu,
		:reg.nroMedidor,
		:reg.marcaMedidor,
		:reg.lecturaFacturacActiva,
		:reg.lecturaTerrenoActiva,
		:reg.consumoActivo,
		:reg.fechaLectura,
		:reg.claveLectura,
		:reg.tipoLectura;
	
	if(SQLCODE != 0)
		return 0;
		
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

