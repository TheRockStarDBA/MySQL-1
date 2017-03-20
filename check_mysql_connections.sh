#!/bin/bash
#
##################################################################
#
#Responsável por monitorar o número de conexões por segundo ao banco de dados. 
#
#O script funciona da seguinte forma: Criamos as variáveis: LASTMYSQLCONNECTIONS e LASTCHECK e populamos as mesmas 
#com os dois valores existentes no arquivo TEMPILE.  Este arquivo, localizado no diretório /tmp, contém dois valores 
#separados por ";' ao qual o primeiro campo é referente a resultado que ele obtém em "Connections" após um select em 
#uma tabela específica no banco de dados, e o segundo campo é obtido através do resultado do comando "date + %s", as duas 
#variáveis que armazena esses dois valores são NOWMYSQLCONNECTIONS e NOWCHECK respectivamente.
#A variável MYSQLCONNECTIONS é populada com a diferença entre  NOWMYSQLCONNECTIONS e LASTMYSQLCONNECTIONS.
#A variavel CHECK é populada com a diferença entre NOWCHECK e LASTCHECK.
#O valor que é obtido após a execução desse script, é o quociente das variáveis  MYSQLCONNECTIONS e CHECK , este valor é 
#armazenado na variavel MYSQLCONPERSECOND.
#É necessário passar 5 argumentos para a execução desse script, conforme o exemplo a seguir: 
#
#################################
TEMPFILE="/tmp/check_mysql_connection_${LOGNAME}.tmp"

#conexoes;data
LASTMYSQLCONNECTIONS=`cat $TEMPFILE | cut -d';' -f1` #define um caractere delimitador ";" e em seguida informa o campo que ele irápassar para a variavel
LASTCHECK=`cat $TEMPFILE | cut -d';' -f2`


HOST="$1"
USER="$2"
PASS="$3"


# Consulta
#NOWMYSQLCONNECTIONS=`mysql -u root -e'select VARIABLE_VALUE from information_schema.GLOBAL_STATUS where variable_name = "Connections"' | tail -n1`
NOWMYSQLCONNECTIONS=`mysql -h $HOST -u $USER -p$PASS -e'select VARIABLE_VALUE from information_schema.GLOBAL_STATUS where variable_name = "Connections"' | tail -n1`
NOWCHECK=`date +%s` #
echo "$NOWMYSQLCONNECTIONS;$NOWCHECK" > $TEMPFILE

if [ $# -lt 3 ]; then
   echo "Faltou utilizar os argumentos corretamente:  [scrip.sh] [host] [user] [pass]"
   exit 4
elif [ $1 == "melanto01" ] && [ $2 == "opuser" ] && [ $3 == "P@ssw0rd" ]; then
   echo "Conection successfull"
   exit 0
fi


#Delta das conexoes mysql
MYSQLCONNECTIONS=$(($NOWMYSQLCONNECTIONS-$LASTMYSQLCONNECTIONS))

# Delta do tempo entre checagens
CHECK=$(($NOWCHECK-$LASTCHECK))

MYSQLCONFORSECOND=$(($MYSQLCONNECTIONS/$CHECK))

#MYSQLCONFORSECOND="8"

if [ -z $MYSQLCONFORSECOND ]; then
   echo "UNKNOWN - Nao foi possivel validar a checagem - STATUS = NULL"
   exit 3
elif ( echo $MYSQLCONFORSECOND | egrep '[:cntrl:]|[:graph:]|[:punct:]' &> /dev/null); then
   echo "UNKNOWN - Nao foi possivel validar a checagem - Caractere invalido"
   exit 3
elif [ $MYSQLCONFORSECOND -lt 100 ]; then
    echo "OK - Numero de acessos por segundo: $MYSQLCONFORSECOND"
    exit 0
elif [ $MYSQLCONFORSECOND -lt 300 ]; then
    echo "WARNING - Numero de acessos por segundo: $MYSQLCONFORSECOND"
    exit 1
else
    echo "CRITICAL - Numero de acessos por segundo: $MYSQLCONFORSECOND"
    exit 2
fi



# Saida do comando
#echo "Todas as conexao no banco -> $MYSQLCONNECTIONS, ultimas coxecao no banco -> $CHECK"
#echo "Conexao por sec no banco $MYSQLCONFORSECOND"
