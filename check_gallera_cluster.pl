#!/usr/bin/perl
#################################################################################################
#                                                                                               #
# Script realiza a verificaÃÃo  de 6 checagens relacionado ao gallera cluster, sendo elas:      #
#                                                                                               #
# clustersize    : Quantidade de nos no Cluster                                                 #
# flwcp          : Controle de fluxo em pausa                                                   #
# localstate     : Controle de fluxo em pausa                                                   #
# connected      : Validar conexÃo com os outros nos do Cluster                                 #
# ready          : Validar se o node estÃo aceitando queries                                    #
# clustersync    : Validar se os servidores estÃ£o sincronizado                                 #
# sendqueueavg   : MÃ©dia de fila de envio de dadosi                                            #
#                                                                                               #
# Criado em: 28/12/2016 por Wagner Garcez                                                       #
# Cliente: Assembleia                                                                           #
#                                                                                               #
#################################################################################################

# ==================== Load Perl modules ======================
use Switch;
use warnings;
use DBI;
use Getopt::Long qw(:config no_ignore_case bundling);
use utf8;

# ======================== Variaveis ==========================
my $num_args = $#ARGV +1;
my $db = 'INFORMATION_SCHEMA';
our ($optType,$optHost,$optUserName,$optPassword,$optCritical,$optWarning,$optFlowControlPaused);

# ================== Consulta ao Banco ========================
sub Consulta{

        my $dbh = DBI->connect("DBI:mysql:database=$db;host=$optHost", $optUserName, $optPassword)
          or print "UNKNOWN - Could not connect to database: $DBI::errstr \n" and  exit(3);
        $sth = $dbh->prepare("SELECT VARIABLE_VALUE FROM INFORMATION_SCHEMA.GLOBAL_STATUS where VARIABLE_NAME LIKE '$row'");
        $sth->execute();
        $result = $sth->fetchrow_array();
        $sth->finish();
        $dbh->disconnect();
}

# ========================== CLUSTER SYNC =============================
sub ClusterSync {

        if ( !defined($optCritical) ) {
                #PrintHelp();
                print "Missing argument : -c|--critical\n";
                exit(3);
        }

        $row = 'wsrep_last_committed';
        $msg = "";
        $i = 0;
        $status=0;
        my @servers = split /,/, $optHost;

        foreach $a (@servers) {
                $optHost = $a;
                Consulta();
                $resultSrv[$i] = $result;
                $i++;
        }

        for ($i = 0; $i < $#resultSrv ; $i ++) {
             if ( abs($resultSrv[$i] - $resultSrv[$i+1]) > $optCritical ) {
                      $msg = "$msg, $servers[$i] and $servers[$i+1]";
                      $status = 2;
                }
        }

        if ($status eq 2) {
                print "CRITICAL: Probleam with $msg \n";
                exit ($status) ;
         }

        print "OK - Cluster Synchronized \n" ;
        exit($status);
}

# ========================== LOCAL STATE  =============================
sub LocaStateComment {
        $row = 'wsrep_local_state_comment';
        Consulta();
        $str = 'Initialized';
        if ( $result ne $str ){
                print "OK - Status = $result \n";
                exit(0);
        } else  {
                print "CRITICAL - Status = $result\n";
                exit(2);
          }
}

# ========================== READY  =============================
sub Ready{
        $row = 'wsrep_ready';
        Consulta();
        $str = 'ON';
        if ( $result eq $str ){
                print "OK - The node ($optHost) can accept queries\n";
                exit(0);
        } else  {
                print "CRITICAL - The node ($optHost) can't accept queries\n";
                exit(2);
          }
}

# ======================= CONNECTED ============================
sub Connected {
        $row = 'wsrep_connected';
        Consulta();
        $str = 'ON';
        if ( $result eq $str ){
                print "OK - The node ($optHost) has network connectivity with any other nodes.\n";
                exit(0);
        } else  {
                print "CRITICAL - The node ($optHost) does not have a connection to any cluster components\n";
                exit(2);
          }
}



# ========================== SIZE =============================
sub ClusterSize {
        if ( !defined($optCritical) ) {
                #PrintHelp();
                print "Missing argument : -c|--critical\n";
                exit(3);
        } else {
                $row = 'wsrep_cluster_size';
                Consulta();
                if ( $result eq $optCritical) {
                        print "OK - Size correct : Quantity of node in cluster = $result \n";
                        exit(0);
                } else  {
                        print "CRITICAL - Size wrong : Quantity of node in cluster = $result\n";
                        exit(2);
                }
        }
}

# ========================== FLOW CONTROL PAUSED =============================
sub FlowControlPaused {
        if ( !defined($optWarning) || !defined($optCritical) ) {
                print "Missing argument : -w or -c\n";
                exit(3);
        } else {
                $row = 'wsrep_flow_control_paused';
                Consulta();
                if ( $result lt $optWarning ) {
                        print "OK - Flow Control Pause = $result |FlowControl_Paused=$result;$optWarning;$optCritical;;\n";
                        exit(0);
                } elsif( $result lt $optCritical ) {
                        print "WARNING - Flow Control Pause = $result |FlowControl_Paused=$result;$optWarning;$optCritical;; \n";
                        exit(1);
                  } else {
                        print "CRITICAL - Flow Control Pause = $result |FlowControl_Paused=$result;$optWarning;$optCritical;; \n";
                        exit(2);
                  }

        }
}

# ========================== SEND QUEUE AVG  =============================
sub SendQueueAvg {
        if ( !defined($optWarning) || !defined($optCritical) ) {
                print "Missing argument : -w or -c\n";
                exit(3);
        } else {
                $row = 'wsrep_local_send_queue_avg';
                Consulta();
                if ( $result lt $optWarning ) {
                        print "OK - Average for the Send Queue = $result |send_queue_avg=$result;$optWarning;$optCritical;;\n";
                        exit(0);
                } elsif( $result lt $optCritical ) {
                        print "WARNING - Average for the Send Queue = $result | send_queue_avg=$result;$optWarning;$optCritical;; \n";
                        exit(1);
                  } else {
                        print "CRITICAL - Average for the Send Queue = $result |send_queue_avg=$result;$optWarning;$optCritical;; \n";
                        exit(2);
                  }
        }
}

# ============================= HELP ==============================
sub PrintHelp {
        print "\nUNKNOWN - Missing arguments. Usage: [script.pl] [parametros]\n";
        print "\n---------------------------- Parametros  ----------------------------------------------------------------\n";
        print "         -h|host=s      => nome do host ou IP\n";
        print "         -u|user=s      => nome do usuario\n";
        print "         -p|pass=s      => senha do usuario\n";
        print "         -w|warning=s   => metrica de warning\n";
        print "         -c|critical=s  => metrica de critical\n";
        print "         -t|--type     => tipo da checagem\n";
        print "                 clustersize     : Quantidade de nÃ³s no Cluster\n";
        print "                 flwcp           : Controle de fluxo em pausa \n";
        print "                 localstate      : Status do nodo³\n";
        print "                 connected       : Validar  com os outros nos do Cluster \n";
        print "                 ready           : Validar se o node estÃ¡ aceitando queries \n";
        print "                 clustersync     : Validar se os servidores estÃ£o sincronizados\n";
        print "                 sendqueueavg    : MÃdia de fila de envio de dados\n";
        print "----------------------------------------------------------------------------------------------------------\n";
        print "\n Exemplos de uso:\n";
        print "\n[script.pl] -t clustersize -h <IP or hostname> -u <user> -p <password> -c <critical>";
        print "\n[script.pl] -t flowcp -h <IP or hostname> -u <user> -p <password> -w <warning> -c <critical>";
        print "\n[script.pl] -t sendqueueavg -h <IP or hostname> -u <user> -p <password> -w <warning> -c <critical>";
        print "\n[script.pl] -t localstate -h <IP or hostname> -u <user> -p <password>";
        print "\n[script.pl] -t connected -h <IP or hostname> -u <user> -p <password>";
        print "\n[script.pl] -t ready -h <IP or hostname> -u <user> -p <password>";
        print "\n[script.pl] -t clustersync-h <IP1 or hostname1,IP2 or hostname2,...> -u <user> -p <password> -c <critical>\n";
        print "\n----------------------------------------------------------------------------------------------------------\n";
        exit(3);
}
# ============================= OPTIONS ARGS  ==============================


# ============================= MAIN ==============================
sub main{

        ParseArgs();
        switch ($optType) {
                case "clustersize"      { ClusterSize() }
                case "ready"            { Ready() }
                case "connected"        { Connected() }
                case "flowcp"           { FlowControlPaused() }
                case "clustersync"      { ClusterSync() }
                case "localstate"       { LocaStateComment() }
                case "sendqueueavg"     { SendQueueAvg() }

        }
}
# ============================= = ==============================
main();
exit;
[root@perseu ~]#
