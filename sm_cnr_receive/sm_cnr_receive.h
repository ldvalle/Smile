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
	long 	nroExpediente;
	char	fechaEstado[20];
	char	estado[4];
	long 	periodoDesde;
	long 	periodoHasta;
	double 	monto;
	
	int		ano_expediente;
	char	cod_estado[3];
	long 	numero_cliente;
	char	cod_provincia[4];
	char	cod_partido[4];
	char	cod_localidad[4];
	char	sucursal_cliente[5];
	int 	sector_cliente;
	int 	zona_cliente;
	char	cod_calle[7];
	char	nro_dir[6];
	char	piso_dir[7];
	char	depto_dir[7];
}ClsCNR;



/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short 	CargarPaths(void);
short 	ArchivoValido(char*);
short 	ProcesaArchivo(void);
void	CargaRegistro( char *, ClsCNR *);
void	InicializoRegistro(ClsCNR *);
short 	VerificaCNR(ClsCNR *);
void 	RegistraLog(char *);

short	AbreArchivos(char *, char *);
void  	CreaPrepare(void);
static char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);


char *substring(char *, int, int);
int  instr(char *, char *);

$endif;
