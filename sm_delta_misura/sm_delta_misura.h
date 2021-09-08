$ifndef SMDELTAMISURA_H;
$define SMDELTAMISURA_H;

#include "ustring.h"
#include "macmath.h"

$include sqltypes.h;
$include sqlerror.h;
$include datetime.h;

#define BORRAR(x)       memset(&x, 0, sizeof x)
#define BORRA_STR(str)  memset(str, 0, sizeof str)

#define SYN_CLAVE "DD_NOVOUT"

/* ---~Estructuras ---*/

$typedef struct{
	long 	lNroCliente;
	long 	lFechaNovedad; 
	char	sTipoOt[3];
	int		iCorrFacturacion;
	int		iEstadoCliente;
	long 	lFechaMoveIn;
	long 	lFechaBaja;	
}ClsCliente;

$typedef struct{
   long     numero_cliente;
   int      corr_facturacion;
   long     fecha_lectura;
   int      tipo_lectura;
   double   lectura_facturac;
   double   lectura_terreno;
   long     numero_medidor;
   char     marca_medidor[4];
   char     clave_lectura[4];
   char     src_deta[21];
   char     src_code[21];
   char     tip_lectu[21];
   char     tip_anom[21];
   char     src_type[21];
   double   lectura_facturac_reac;
   char		flag_migrado[2];
   char		flag_consumo_pendiente[2];
}ClsLectura;


/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  	CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );

short	LeoCliente( ClsCliente *);
void	InicializaCliente(ClsCliente *);
short	LeoLecturasAct(long, int, ClsLectura *, long);
short	LeoLecturaPend(long, int, ClsLectura *);
short	LeoLecturas(ClsLectura *, long, char *);
void 	InicializaLectura(ClsLectura *);

void	GenerarPlanoMisura(ClsLectura, int, int, long);
void	GenerarPlanoAdjunto(ClsLectura, int, int, long);

int		getCorrelativoLectu(long, int);
char 	*strReplace(char *, char *, char *);
char	*getEmplazaSAP(char*);
char	*getEmplazaT23(char*);
void	CerrarArchivos(void);
void	MoverArchivos(int);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
