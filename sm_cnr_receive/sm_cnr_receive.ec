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

$include "sm_sm_cnr_receive.h";

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
			
			cantLecturas++;
			CargaRegistro( sLinea, &reg);

			strcpy(sMsg, "\tLinea Procesada\n");
			RegistraLog(sMsg);
			fflush(pFileLog);
	
memset(sMsg, '\0', sizeof(sMsg));
sprintf(sMsg,"Cliente %ld", reg.nroCliente);
sprintf(sMsg, "%s Tarifa %s", sMsg, reg.sTipoTarifa);	
sprintf(sMsg, "%s Medidor %ld %s %s ", sMsg, reg.nroMedidor, reg.marcaMedidor, reg.modeloMedidor);	
sprintf(sMsg, "%s Tarifa %s", sMsg, reg.sTipoTarifa);	
sprintf(sMsg, "%s Lectura Facturac %f Lectura Terreno %f Consumo %ld ", sMsg, reg.lecturaFacturacActiva, reg.lecturaTerrenoActiva, reg.consumoActivo);
sprintf(sMsg, "%s Fecha Lectura %ld Tipo Lectura %d \n", sMsg, reg.fechaLectura, reg.tipoLectura);
/*			
			if(strcmp(reg.sTipoTarifa, "T1")==0){
				iCorrFactu=0;
				if(VerificaCliente(&iCorrFactu, reg.nroCliente)){
					$BEGIN WORK;
					
					if(reg.fechaAjuste==0){
						if(!CargaLecturaFacturada(iCorrFactu, reg)){
							$ROLLBACK WORK;
							sprintf(sMsg, "Facturada Erronea [%s]\n", sLinea);
							RegistraLog(sMsg);
						}
					}else{
						if(!CargaLecturaAjustada(reg)){
							$ROLLBACK WORK;
							sprintf(sMsg, "Ajustada Erronea [%s]\n", sLinea);
							RegistraLog(sMsg);
						}
					}
					
					$COMMIT WORK;
				}else{
					sprintf(sMsg, "No Verifica Cliente [%s]\n", sLinea);
					RegistraLog(sMsg);
				}
			}
*/			
			
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

	/* ID Calculo */
	if (RetornaCampoVar(sCampo, sLinea, '|', 2)){
		strcpy(reg->idSimulacion, sCampo);
		alltrim(reg->idSimulacion, ' ');
	}

	/* Fecha Estado */
	if (RetornaCampoVar(sCampo, sLinea, '|', 3)){
		strcpy(reg->fechaEstado, sCampo);
	}

	/* Rol Estado */
	if (RetornaCampoVar(sCampo, sLinea, '|', 4)){
		strcpy(reg->rolEstado, sCampo);
	}
	
	/* Estado */
	if (RetornaCampoVar(sCampo, sLinea, '|', 5)){
		strcpy(reg->estado, sCampo);
	}
	
	/* Anomalia */
	if (RetornaCampoVar(sCampo, sLinea, '|', 6)){
		strcpy(reg->anomalia, sCampo);
		alltrim(reg->anomalia, ' ');
	}
	
	/* Periodo Desde */
	if (RetornaCampoVar(sCampo, sLinea, '|', 7)){
		rdefmtdate(&(reg->periodoDesde), "dd/mm/yyyy", sCampo);
	}

	/* Periodo Hasta */
	if (RetornaCampoVar(sCampo, sLinea, '|', 8)){
		rdefmtdate(&(reg->periodoHasta), "dd/mm/yyyy", sCampo);
	}
	
	/* Monto Sin Impuestos*/
	if (RetornaCampoVar(sCampo, sLinea, '|', 9)){
		reg->lecturaFacturacActiva = atof(sCampo);
	}
	
	/* Lectura Facturada ReActiva*/
	if (RetornaCampoVar(sCampo, sLinea, '|', 16)){
		alltrim(sCampo, ' ');
		if(strcmp(sCampo, "")!= 0)
			reg->lecturaFacturacReactiva = atof(sCampo);
	}
	
	/* Tipo Lectura */
	if (RetornaCampoVar(sCampo, sLinea, '|', 23)){
		alltrim(sCampo, ' ');
		reg->tipoLectura = atoi(sCampo);
	}
	
	/* Consumo Activa */
	if (RetornaCampoVar(sCampo, sLinea, '|', 28)){
		reg->consumoActivo = atol(sCampo);
	}
	
	/* Consumo Reactiva */
	if (RetornaCampoVar(sCampo, sLinea, '|', 29)){
		alltrim(sCampo, ' ');
		if(strcmp(sCampo, "")!= 0)
			reg->consumoReactivo = atol(sCampo);
	}
	
	/* Clave Lectura */
	if (RetornaCampoVar(sCampo, sLinea, '|', 36)){
		alltrim(sCampo, ' ');
		strcpy(reg->claveLectura, sCampo);
	}

	
	/* LecturaTerreno Activa */
	if (RetornaCampoVar(sCampo, sLinea, '|', 41)){
		reg->lecturaTerrenoActiva = atof(sCampo);
	}
	
	/* LecturaTerreno ReActiva */
	if (RetornaCampoVar(sCampo, sLinea, '|', 42)){
		alltrim(sCampo, ' ');
		if(strcmp(sCampo, "")!= 0 )
			reg->lecturaTerrenoReactiva = atof(sCampo);
	}
	
	
	/* Constante */
	reg->constante = 1;
	
	/* Correlativo Contador */
	reg->correlContador = 1;
	
	/* Coseno Phi */
	
	/* Fecha Ajuste */
	if (RetornaCampoVar(sCampo, sLinea, '|', 56)){
		alltrim(sCampo, ' ');
		if(strcmp(sCampo, "31/12/9999 23:59:59")==0){
			reg->fechaAjuste=0;
		}else{
			reg->fechaAjuste=1;
		}
		/*rdefmtdate(&(reg->fechaAjuste), "dd/mm/yyyy HH:MM:SS", sCampo)*/
	}




}

void InicializoRegistro(reg)
$ClsCNR	*reg;
{
	memset(reg->sucursal, '\0', sizeof(reg->sucursal));
	rsetnull(CLONGTYPE, (char *) &(reg->nroExpediente));
	memset(reg->idSimulacion, '\0', sizeof(reg->idSimulacion));
	memset(reg->fechaEstado, '\0', sizeof(reg->fechaEstado));
	memset(reg->rolEstado, '\0', sizeof(reg->rolEstado));
	memset(reg->estado, '\0', sizeof(reg->estado));
	memset(reg->anomalia, '\0', sizeof(reg->anomalia));
	rsetnull(CLONGTYPE, (char *) &(reg->periodoDesde));
	rsetnull(CLONGTYPE, (char *) &(reg->periodoHasta));
	rsetnull(CDOUBLETYPE, (char *) &(reg->montoSinImpuestos));
	rsetnull(CDOUBLETYPE, (char *) &(reg->montoConImpuestos));
	rsetnull(CLONGTYPE, (char *) &(reg->fechaFacturacion));
	rsetnull(CLONGTYPE, (char *) &(reg->fechaVcto));
	rsetnull(CLONGTYPE, (char *) &(reg->kwhRecuperados));
	memset(reg->tipoCnr, '\0', sizeof(reg->tipoCnr));
	
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
		constante,
		correl_contador
		)VALUES(?,?,?,?,?,?,?,?,?,?,1,1) ";
		
	/** Inserta Hislec Reac **/
	$PREPARE insHislecReac FROM "INSERT INTO hislec_reac(
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
		)VALUES(?,?,?,?,?,?,?,?,?,100) ";

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

	/* Trae Lectura original */
	$PREPARE selLectuOrigin FROM "SELECT corr_facturacion FROM hislec
		WHERE numero_cliente = ?
		AND fecha_lectura = ?
		AND tipo_lectura = ? ";

	/* Trae Correlativo de Refac */
	$PREPARE selCorrRefac FROM "SELECT NVL(MAX(corr_refacturacion),0) FROM hislec_refac
		WHERE numero_cliente = ? ";
		
	/* Trae Correlativo de Hislec Refac */
	$PREPARE selCorrHislecRefac FROM "SELECT NVL(MAX(corr_hislec_refac), 0) FROM hislec_refac
		WHERE numero_cliente = ? ";
	
	/* Graba Hislec Refac */
	$PREPARE insHislecRefac FROM "INSERT INTO hislec_refac (numero_cliente, corr_facturacion, corr_refacturacion, 
		numero_medidor, marca_medidor, correl_contador, tipo_lectura, fecha_lectura,
		lectura_rectif, consumo_rectif, refacturado, corr_hislec_refac
		)VALUES(?, ?, ?, 
		?, ?, 1, ?, ?,
		?, ?, 'S', ?) ";

	/* Graba Hislec Refac Reac */
	$PREPARE insHislecRefacReac FROM "INSERT INTO hislec_refac_reac (numero_cliente, corr_facturacion, corr_refacturacion,
		numero_medidor, marca_medidor, tipo_lectura, fecha_lectura, lectu_rectif_reac,
		consu_rectif_reac, refacturado, corr_hislec_refac, coseno_phi
		)VALUES(?, ?, ?,
		?, ?, ?, ?, ?,
		?, 'S', ?, 100) ";

	/* Sel Correlativo Cliente */
	$PREPARE selCorrCliente FROM "SELECT corr_facturacion FROM cliente WHERE numero_cliente = ? ";
}


void RegistraLog(sLinea)
char	*sLinea;
{
	
	fprintf(pFileLog, sLinea);
	
}




short VerificaCliente(icorrFactu, nroCliente)
$int	*icorrFactu;
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
		/* Actualiza medidor 2 */
		$EXECUTE updMedid2 USING :reg.lecturaFacturacActiva, :reg.lecturaFacturacReactiva, 
			:reg.nroCliente, :reg.nroMedidor, :reg.marcaMedidor;
		
		if(SQLCODE != 0){
			sprintf(sMsg, "Cliente %ld Fallo UpdMedid2\n", reg.nroCliente);
			RegistraLog(sMsg);
			return 0;			
		}
	}else{
		/* Actualiza Medidor 1 */
		$EXECUTE updMedid USING :reg.lecturaFacturacActiva 
			:reg.nroCliente, :reg.nroMedidor, :reg.marcaMedidor;
		
		if(SQLCODE != 0){
			sprintf(sMsg, "Cliente %ld Fallo UpdMedid1\n", reg.nroCliente);
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
		:reg.lecturaFacturacActiva,
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
		:reg.lecturaFacturacActiva,
		:reg.consumoActivo,
		:reg.fechaLectura,
		:reg.claveLectura,
		:reg.tipoLectura;
	
	if(SQLCODE != 0)
		return 0;
		
	return 1;
}


short CargaLecturaAjustada(reg)
$ClsLectura reg;
{
	$int 	iCorrFactu=0;
	$int	iCorrRefactu=0;
	$int	iCorrHislecRefac=0;
	char 	sMsg[1000];
	
	memset(sMsg, '\0', sizeof(sMsg));
	
	/* Buscar lectura original */
	$EXECUTE selLectuOri INTO :iCorrFactu USING :reg.nroCliente, :reg.fechaLectura, :reg.tipoLectura;
	
	if(SQLCODE !=0){
		sprintf(sMsg, "Cliente %ld Fecha Lectura %ld Tipo Lectura %d No se pudo encontrar.\n", reg.nroCliente, reg.fechaLectura, reg.tipoLectura);
		RegistraLog(sMsg);
		return 0;
	}
	
	/* Trae Correlativo de Refac */
	$EXECUTE selCorrRefac INTO :iCorrRefactu USING :reg.nroCliente;
	
	iCorrRefactu++;
		
	/* Trae Correlativo de Hislec Refac */
	$EXECUTE selCorrHislecRefac INTO :iCorrHislecRefac USING :reg.nroCliente;
	
	iCorrHislecRefac++;
	
	/* Grabar Hislec Refac */
	if(!GrabaAjusteActiva(iCorrFactu, iCorrRefactu, iCorrHislecRefac, reg)){
		sprintf(sMsg, "Cliente %ld Fallo GrabaAjusteActiva\n", reg.nroCliente);
		RegistraLog(sMsg);
		return 0;		
	}
	
	if(!risnull(CLONGTYPE, (char *) &(reg.consumoReactivo))){
		/* Grabar Hislec Refac Reac*/
		if(!GrabaAjusteReActiva(iCorrFactu, iCorrRefactu, iCorrHislecRefac, reg)){
			sprintf(sMsg, "Cliente %ld Fallo GrabaAjusteReActiva\n", reg.nroCliente);
			RegistraLog(sMsg);
			return 0;		
		}
		
		if(EsUltimaLectura(iCorrFactu, reg)){
			/* Actualiza medidor 2 */
			$EXECUTE updMedid2 USING :reg.lecturaFacturacActiva, :reg.lecturaFacturacReactiva, 
				:reg.nroCliente, :reg.nroMedidor, :reg.marcaMedidor;
			
			if(SQLCODE != 0){
				sprintf(sMsg, "Cliente %ld Fallo UpdMedid2\n", reg.nroCliente);
				RegistraLog(sMsg);
				return 0;			
			}			
		}
	
	}else{
		if(EsUltimaLectura(iCorrFactu, reg)){
			/* Actualiza medidor 1 */
			$EXECUTE updMedid1 USING :reg.lecturaFacturacActiva
				:reg.nroCliente, :reg.nroMedidor, :reg.marcaMedidor;
			
			if(SQLCODE != 0){
				sprintf(sMsg, "Cliente %ld Fallo UpdMedid1\n", reg.nroCliente);
				RegistraLog(sMsg);
				return 0;			
			}			
		}		
	}
	
	return 1;
}

short GrabaAjusteActiva(iCorrFactu, iCorrRefactu, iCorrHislecRefac, reg)
$int		iCorrFactu;
$int		iCorrRefactu;
$int		iCorrHislecRefac;
$ClsLectura	reg;
{
	
	$EXECUTE insHisleRefac USING
		:reg.nroCliente,
		:iCorrFactu,
		:iCorrRefactu,
		:reg.nroMedidor,
		:reg.marcaMedidor,
		:reg.tipoLectura,
		:reg.fechaLectura,
		:reg.lecturaFacturacActiva,
		:reg.consumoActivo,
		:iCorrHislecRefac;
	
	if(SQLCODE != 0)
		return 0;
		
	return 1;
}

short GrabaAjusteReActiva(iCorrFactu, iCorrRefactu, iCorrHislecRefac, reg)
$int	iCorrFactu;
$int	iCorrRefactu;
$int	iCorrHislecRefac;
$ClsLectura	reg;
{
	
	$EXECUTE insHislecRefacReac USING
		:reg.nroCliente,
		:iCorrFactu,
		:iCorrRefactu,
		:reg.nroMedidor,
		:reg.marcaMedidor,
		:reg.tipoLectura,
		:reg.fechaLectura,
		:reg.lecturaFacturacReactiva,
		:reg.consumoReactivo,
		:iCorrHislecRefac;
		
	if(SQLCODE != 0)
		return 0;
	
	return 1;
}

short EsUltimaLectura(iCorrFactu, reg)
$int	iCorrFactu;
$ClsLectura	reg;
{
	$int corrFacturacion=0;
	
	$EXECUTE selCorrCliente INTO :corrFacturacion USING :reg.nroCliente;
	
	if(corrFacturacion==iCorrFactu){
		return 1;
	}else{
		return 0;
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

