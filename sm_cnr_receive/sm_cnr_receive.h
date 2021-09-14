$ifndef CNRRECEIVE_H;
$define CNRRECEIVE_H_H;

#include "ustring.h"
#include "macmath.h"

$include sqltypes.h;
$include sqlerror.h;
$include datetime.h;

#define BORRAR(x)       memset(&x, 0, sizeof x)
#define BORRA_STR(str)  memset(str, 0, sizeof str)


/*--- Estructuras ---*/

$typedef struct{
	char	sucursal[5];
	long	nroExpediente;
	char	idSimulacion[5];
	char 	fechaEstado[20];
	char	rolEstado[20];
	char	estado[4];
	char	anomalia[251];
	long 	periodoDesde;
	long 	periodoHasta;
	double 	montoSinImpuestos;
	double 	montoConImpuestos;
	long 	fechaFacturacion;
	long 	fechaVcto;
	long 	kwhRecuperados;
	char	tipoCnr[4];
}ClsCNR;



/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short 	CargarPaths(void);
short 	ArchivoValido(char*);
short 	ProcesaArchivo(void);
void	CargaRegistro( char *, ClsCNR *);
void	InicializoRegistro(ClsCNR *);
short 	ValidoRegistro(ClsCNR);
void 	RegistraLog(char *);

short	AbreArchivos(char *, char *);
void  	CreaPrepare(void);
static char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);

short VerificaCliente(int *, long);
short CargaLecturaFacturada( int, ClsLectura );
short GrabaLectuActiva(int, ClsLectura);
short GrabaLectuReActiva(int, ClsLectura);

short CargaLecturaAjustada(ClsLectura);
short GrabaAjusteActiva(int, int, int, ClsLectura);
short GrabaAjusteReActiva(int, int, int, ClsLectura);
short EsUltimaLectura(int, ClsLectura);

char *substring(char *, int, int);
int  instr(char *, char *);

$endif;
