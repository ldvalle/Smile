$ifndef SMAGENDA_H;
$define SMAGENDA_H;

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
   int   sector;
   char  anoMes[7];
   char  dataTablaLectu[11];
   char  dataLectura[11];
   char  dataFacturacion[11];
   char  centroOp[2];
   char  porcion[9];
   char  ul[9];
   char  sFechaCierrePropuesta[11];
   char  sFechaCierre[11];
}ClsAgenda;



/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
long  getCorrelativo(char*);

short LeoAgenda(ClsAgenda *);
void  InicializaAgenda(ClsAgenda *);
void  GenerarPlanos(FILE*, ClsAgenda);

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
