$ifndef SMCNRSEND_H;
$define SMCNRSEND_H;

#include "ustring.h"
#include "macmath.h"

$include sqltypes.h;
$include sqlerror.h;
$include datetime.h;

#define BORRAR(x)       memset(&x, 0, sizeof x)
#define BORRA_STR(str)  memset(str, 0, sizeof str)

#define SYN_CLAVE "DD_NOVOUT"

/* Estructuras ***/
$typedef struct{
	long 	numero_cliente;
	char	cod_estado[3];
	char 	fecha_inicio[20];
	char	id_expediente[15];
	char	fecha_inspeccion[20];
	char	tipo_expediente[2];
	char	anomalia[70];
}ClsCNR;



/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  	CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );


short LeoCNR(ClsCNR *);
void  InicializaCNR(ClsCNR *);
void  GenerarPlanos(FILE*, ClsCNR);

char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(char*, int);
void  MueveArchivos(void);


/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
