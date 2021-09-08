$ifndef CARGALECTURAS_H;
$define CARGALECTURAS_H_H;

#include "ustring.h"
#include "macmath.h"

$include sqltypes.h;
$include sqlerror.h;
$include datetime.h;

#define BORRAR(x)       memset(&x, 0, sizeof x)
#define BORRA_STR(str)  memset(str, 0, sizeof str)


/*--- Estructuras ---*/

$typedef struct{
	long 	nroCliente;
	int		corrFacturacion;
	long 	nroMedidor;
	char	marcaMedidor[4];
	float 	lecturaFacturacActiva;
	float 	lecturaTerrenoActiva;

	float 	lecturaFacturacReactiva;
	float 	lecturaTerrenoReactiva;

	long 	consumoActivo;
	long 	consumoReactivo;
	
	long 	fechaLectura;
	char	claveLectura[4];
	int		tipoLectura;
	float 	constante;
	int		correlContador;
	char	tipoEnergia[2];
	float 	cosPhi;
	long 	fechaAjuste;
}ClsLectura;



/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short 	CargarPaths(void);
short 	ArchivoValido(char*);
short 	ProcesaArchivo(void);
void	CargaRegistro( char *, ClsLectura *);
void	InicializoRegistro(ClsLectura *);
short 	ValidoRegistro(ClsLectura);
void 	RegistraLog(char *);

short	AbreArchivos(char *, char *);
void  	CreaPrepare(void);
static char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);

short VerificaCliente(int *, long);
short CargaLecturaFacturada( int, ClsLectura );
short GrabaLectuActiva(int, ClsLectura);
short GrabaLectuReActiva(int, ClsLectura);

char *substring(char *, int, int);
int  instr(char *, char *);

$endif;
